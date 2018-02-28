/*
 * Copyright ActionML, LLC under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * ActionML licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.actionml.admin

import java.lang.reflect.Constructor

import cats.data.Validated
import cats.data.Validated.{Invalid, Valid}
import com.actionml.core.core._
import com.actionml.core.storage.Mongo
import com.actionml.core.model.GenericEngineParams
import com.actionml.core._
import com.actionml.core.model.GenericEngineParams
import com.actionml.core.storage.Mongo
import com.actionml.core.template.Engine
import com.actionml.core.validate._
import org.mongodb.scala.MongoCollection
import org.mongodb.scala.bson.collection.immutable.Document
import scaldi.{Injector, Module}

import scala.concurrent.{ExecutionContext, Future}
import scala.util.{Failure, Success, Try}

class MongoAdministrator(override implicit val injector: Module)
  extends Administrator with JsonParser with Mongo {

  lazy val enginesCollection: MongoCollection[Engine] = getDatabase("harness_meta_store").getCollection("engines")
  lazy val commandsCollection: MongoCollection[Engine] = getDatabase("harness_meta_store").getCollection("commands") // async persistent though temporary commands
  var engines = Map.empty[EngineId, Engine]

  drawActionML
  private def newEngineInstance(engineFactory: String): Engine = {
    //Class.forName(engineFactory).newInstance().asInstanceOf[Engine]
    //val c = Class.getDeclaredConstructor(String.class).newInstance("HERESMYARG")
    val v = Class.forName(engineFactory).getConstructors
    val c = Injector.getClass
    val c2 = classOf[Injector]
    Class.forName(engineFactory).getDeclaredConstructor(classOf[Injector]).newInstance(injector).asInstanceOf[Engine]
  }

  // instantiates all stored engine instances with restored state
  override def init()(implicit ec: ExecutionContext): Future[MongoAdministrator] = {
    def initEngine(engine: Engine): Future[Try[Engine]] = {
      val params = engine.engineParams
      newEngineInstance(engine.engineFactory)
        .initAndGet(params)
        .map(Success(_))
        .recoverWith { case error =>
          // it is possible that previously valid metadata is now bad, the Engine code must have changed
          logger.error(s"Error creating engineId: ${engine.engineId} from $params" +
            s"\n\nTrying to recover by deleting the previous Engine metadata but data may still exist for this Engine, which you must " +
            s"delete by hand from whatever DB the Engine uses then you can re-add a valid Engine JSON config and start over. Note:" +
            s"this only happens when code for one version of the Engine has chosen to not be backwards compatible.")
          // Todo: we need a way to cleanup in this situation
          enginesCollection.deleteOne(Document("engineId" -> engine.engineId)).toFuture().map(_ => Failure(error))
          // can't do this because the instance is null: deadEngine.destroy(), maybe we need a compan ion object with a cleanup function?
        }
    }
    // ask engines to init
    (for {
      engines <- enginesCollection.find.toFuture
      initializedEngines <- Future.sequence(engines.map(initEngine))
    } yield initializedEngines.collect { case Success(e) => e })
      .map { engines =>
        drawInfo("Harness Server Init", Seq(
          ("════════════════════════════════════════", "══════════════════════════════════════"),
          ("Number of Engines: ", engines.size),
          ("Engines: ", engines.map(_.engineId))))
        this.engines = engines.map(e => e.engineId -> e).toMap
        this
      }
  }

  def getEngine(engineId: EngineId): Option[Engine] = {
    engines.get(engineId)
  }

  /*
  POST /engines/<engine-id>
  Request Body: JSON for engine configuration engine.json file
    Response Body: description of engine-instance created.
  Success/failure indicated in the HTTP return code
  Action: creates or modifies an existing engine
  */
  def addEngine(json: String): Validated[ValidateError, EngineId] = {
    // val params = parse(json).extract[GenericEngineParams]
    /* TODO: implement
    parseAndValidate[GenericEngineParams](json).andThen { params =>
      val newEngine = newEngineInstance(params.engineFactory).initAndGet(json)
      if (newEngine != null && enginesCollection.find(MongoDBObject("engineId" -> params.engineId)).size == 1) {
        // re-initialize
        logger.trace(s"Re-initializing engine for resource-id: ${ params.engineId } with new params $json")
        val query = MongoDBObject("engineId" -> params.engineId)
        val update = MongoDBObject("$set" -> MongoDBObject("engineFactory" -> params.engineFactory, "params" -> json))
        enginesCollection.findAndModify(query, update)
        Valid(params.engineId)
      } else if (newEngine != null) {
        //add new
        engines += params.engineId -> newEngine
        logger.trace(s"Initializing new engine for resource-id: ${ params.engineId } with params $json")
        val builder = MongoDBObject.newBuilder
        builder += "engineId" -> params.engineId
        builder += "engineFactory" -> params.engineFactory
        builder += "params" -> json
        enginesCollection += builder.result()
        Valid(params.engineId)

      } else {
        // ignores case of too many engine with the same engineId
        Invalid(ParseError(s"Unable to create Engine: ${params.engineId}, the config JSON seems to be in error"))
      }
    }
    */
    ???
  }

  override def removeEngine(engineId: String): Validated[ValidateError, Boolean] = {
    /* TODO: implement
    if (engines.contains(engineId)) {
      logger.info(s"Stopped and removed engine and all data for id: $engineId")
      val deadEngine = engines(engineId)
      engines = engines - engineId
      enginesCollection.remove(MongoDBObject("engineId" -> engineId))
      deadEngine.destroy()
      Valid(true)
    } else {
      logger.warn(s"Cannot remove non-existent engine for id: $engineId")
      Invalid(WrongParams(s"Cannot remove non-existent engine for id: $engineId"))
    }
    */
    ???
  }

  override def status(resourceId: Option[String] = None): Validated[ValidateError, String] = {
    if (resourceId.nonEmpty) {
      if (engines.contains(resourceId.get)) {
        logger.trace(s"Getting status for ${resourceId.get}")
        Valid(engines(resourceId.get).status().toString)
      } else {
        logger.error(s"Non-existent engine-id: ${resourceId.get}")
        Invalid(WrongParams(s"Non-existent engine-id: ${resourceId.get}"))
      }
    } else {
      logger.trace("Getting status for all Engines")
      Valid(engines.mapValues(_.status()).toSeq.mkString("\n"))
    }
  }

  override def updateEngine(json: String): Validated[ValidateError, String] = {
    /* TODO: implement:
    parseAndValidate[GenericEngineParams](json).andThen { params =>
      engines.get(params.engineId).map { existingEngine =>
        logger.trace(s"Re-initializing engine for resource-id: ${params.engineId} with new params $json")
        val query = MongoDBObject("engineId" -> params.engineId)
        val update = MongoDBObject("$set" -> MongoDBObject("engineFactory" -> params.engineFactory, "params" -> json))
        enginesCollection.findAndModify(query, update)
        existingEngine.init(json).andThen(_ => Valid(
          """{
            |  "comment":"Get engine status to see what was changed."
            |}
          """.stripMargin))
      }.getOrElse(Invalid(WrongParams(s"Unable to update Engine: ${params.engineId}, the engine does not exist")))
    }
    */
    ???
  }

}

