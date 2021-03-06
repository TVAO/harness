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

package com.actionml.authserver.dal.mongo

import com.actionml.authserver.dal.RoleSetsDao
import com.actionml.authserver.model.RoleSet
import scaldi.{Injectable, Injector}
import org.mongodb.scala.model.Filters._

import scala.concurrent.{ExecutionContext, Future}

class RoleSetsDaoImpl(implicit inj: Injector) extends RoleSetsDao with Injectable with MongoSupport {
  private implicit val _ = inject[ExecutionContext]
  private lazy val roleSets = collection[RoleSet]("roleSets")

  override def find(id: String): Future[Option[RoleSet]] = {
    roleSets.find(equal("id", id))
      .toFuture()
      .map(_.headOption)
  }
}
