#!/usr/bin/env bash

echo
echo "Usage: contextual-bandit-integration-test.sh"
echo "run from harness/java-sdk or from the integration-test.sh"
echo "Make sure to set export HARNESS_CA_CERT=/path/to/harness.pem!!! or all sending to Harness will fail."
echo

# several flags are passed in via export from the integration test, otherwise they are undefined
# so this script will execute the defaults


# point to the harness host, use https://... for SSL and set the credentials if using Auth
# export "HARNESS_CLIENT_USER_ID"=xyz
# export "HARNESS_CLIENT_USER_SECRET"=abc
host=localhost
engine_1=test_cb
engine_2=test_cb_2
#test_queries=data/2-user-query.json
#engine_1_behavior_events=data/joe-context-tags-2.json
#engine_1_profile_events=data/joe-profile-location.json
#engine_2_behavior_events=data/john-context-tags-2.json
#engine_2_profile_events=data/john-profile-location.json
sleep_seconds=1

# export HARNESS_CA_CERT=/Users/pat/harness/rest-server/server/src/main/resources/keys/harness.pem
cd example

# initialize these in case not running from integrated test script
skip_restarts=${skip_restarts:-false}
clean_test_artifacts=${clean_test_artifacts:-false}


echo
echo "----------------------------------------------------------------------------------------------------------------"
echo "TESTING SIMILAR PROFILES, 2 PEOPLE $set, INTO 2 DIFFERENT ENGINES"
echo "----------------------------------------------------------------------------------------------------------------"
harness delete $engine_1
sleep $sleep_seconds
harness delete $engine_2
sleep $sleep_seconds
harness add data/$engine_1.json
sleep $sleep_seconds
harness add data/$engine_2.json
harness status
harness status engines

# The test is to create 2 engines, 2 users with profile data convert on the same variant in one engine and only
# one user converts on a variant on the second engine. both engines should return the same variant for both users
# because profile is in common.

echo
echo "Sending events to create testGroup: 1, user: joe, and one conversion event with location new york to test_cb"
echo
#mvn compile
# mvn exec:java -Dexec.mainClass="EventsClientExample" -Dexec.args="$1 $2 $3" -Dexec.cleanupDaemonThreads=false
mvn exec:java -Dexec.mainClass="EventsClientExample" -Dexec.args="$host $engine_1 data/joe-profile-location.json" -Dexec.cleanupDaemonThreads=false

echo
echo "Sending events to create testGroup: 1, user: john, and one conversion event with location new york to test_cb"
echo
mvn exec:java -Dexec.mainClass="EventsClientExample" -Dexec.args="$host $engine_1 data/john-profile-location.json" -Dexec.cleanupDaemonThreads=false

echo
echo "Sending events to create testGroup: 1, user: john, and one conversion event with location new york to test_cb_2"
echo
mvn exec:java -Dexec.mainClass="EventsClientExample" -Dexec.args="$host $engine_2 data/joe-profile-location.json" -Dexec.cleanupDaemonThreads=false

echo "================================== Before restart queries =================================="
echo "================================== Before restart queries ==================================" > test-profile-results.txt
echo
echo "Sending queries for joe and john to test_cb"
echo
mvn exec:java -Dexec.mainClass="QueriesClientExample" -Dexec.args="$host $engine_1 data/2-user-query.json" -Dexec.cleanupDaemonThreads=false >> test-profile-results.txt

echo
echo "Sending queries for joe and john to test_cb_2"
echo
mvn exec:java -Dexec.mainClass="QueriesClientExample" -Dexec.args="$host $engine_2 data/2-user-query.json" -Dexec.cleanupDaemonThreads=false >> test-profile-results.txt

echo
echo "----------------------------------------------------------------------------------------------------------------"
echo "TESTING CONTEXTUAL BANDIT MODEL PERSISTENCE BY RESTARTING HARNESS AND MAKING QUERIES"
echo "The results should be the same as before the restart"
echo "----------------------------------------------------------------------------------------------------------------"
echo

echo "Harness running, queries return correct results"
ls -al /tmp/harness/models/

if [ "$skip_restarts" == false ]; then
    sleep 10
    harness stop
    echo "Stopped, model persisted"
    ls -al /tmp/harness/models/
    #sleep 10
    harness start -f
fi

echo "Started, models ussed to initilaize"
ls -al /tmp/harness/models/

echo "================================== After restart queries =================================="
echo "================================== After restart queries ==================================" >> test-profile-results.txt
echo
echo "Sending queries for joe and john to test_cb"
echo
mvn exec:java -Dexec.mainClass="QueriesClientExample" -Dexec.args="$host $engine_1 data/2-user-query.json" -Dexec.cleanupDaemonThreads=false >> test-profile-results.txt

echo
echo "Sending queries for joe and john to test_cb_2"
echo
mvn exec:java -Dexec.mainClass="QueriesClientExample" -Dexec.args="$host $engine_2 data/2-user-query.json" -Dexec.cleanupDaemonThreads=false >> test-profile-results.txt

echo
echo "----------------------------------------------------------------------------------------------------------------"
echo "TESTING SIMILAR BEHAVIORS, 2 PEOPLE'S CONVERSIONS, INTO 2 DIFFERENT ENGINES"
echo "----------------------------------------------------------------------------------------------------------------"
echo
harness delete $engine_1
sleep $sleep_seconds
harness delete $engine_2
sleep $sleep_seconds
harness add data/$engine_1.json
sleep $sleep_seconds
harness add data/$engine_2.json
harness status
harness status engines

# The test is to create 2 engines, 2 users with tag preference behavioral data convert on the same variant in one engine and
# only one user converts on a variant on the second engine. both engines should return the same variant for both users
# because tag preferences are in common is in common.

echo
echo "Sending events to create testGroup: 1, user: joe, and one conversion event with no contextualTags to test_cb"
echo
#mvn compile
# mvn exec:java -Dexec.mainClass="EventsClientExample" -Dexec.args="$1 $2 $3" -Dexec.cleanupDaemonThreads=false
mvn exec:java -Dexec.mainClass="EventsClientExample" -Dexec.args="$host $engine_1 data/joe-context-tags-2.json" -Dexec.cleanupDaemonThreads=false

echo
echo "Sending events to create testGroup: 1, user: john, and one conversion event with no contextualTags to test_cb_2"
echo
mvn exec:java -Dexec.mainClass="EventsClientExample" -Dexec.args="$host $engine_1 data/john-context-tags-2.json" -Dexec.cleanupDaemonThreads=false

echo
echo "Sending events to create testGroup: 1, user: john, and one conversion event with no contextualTags to test_cb_2"
echo
mvn exec:java -Dexec.mainClass="EventsClientExample" -Dexec.args="$host $engine_2 data/joe-context-tags-2.json" -Dexec.cleanupDaemonThreads=false

echo "================================== Before restart behavior queries =================================="
echo "================================== Before restart behavior queries ==================================" > test-behavior-results.txt
echo
echo "Sending queries for joe and john to test_cb"
echo

mvn exec:java -Dexec.mainClass="QueriesClientExample" -Dexec.args="$host $engine_1 data/2-user-query.json" -Dexec.cleanupDaemonThreads=false >> test-behavior-results.txt

echo
echo "Sending queries for joe and john to test_cb_2"
echo
mvn exec:java -Dexec.mainClass="QueriesClientExample" -Dexec.args="$host $engine_2 data/2-user-query.json" -Dexec.cleanupDaemonThreads=false >> test-behavior-results.txt


echo
echo "----------------------------------------------------------------------------------------------------------------"
echo "TESTING CONTEXTUAL BANDIT MODEL PERSISTENCE BY RESTARTING HARNESS AND MAKING QUERIES"
echo "The results should be the same as before the restart"
echo "----------------------------------------------------------------------------------------------------------------"
echo

echo "Harness running, queries return correct results"
ls -al /tmp/harness/models/

if [ "$skip_restarts" == false ]; then
    sleep 10
    harness stop
    echo "Stopped, model persisted"
    ls -al /tmp/harness/models/
    #sleep 10
    harness start -f
fi

echo "Started, models ussed to initilaize"
ls -al /tmp/harness/models/

echo
echo "Sending queries for joe and john to test_cb"
echo
echo "================================== After restart queries =================================="
echo "================================== After restart queries ==================================" >> test-behavior-results.txt
mvn exec:java -Dexec.mainClass="QueriesClientExample" -Dexec.args="$host $engine_1 data/2-user-query.json" -Dexec.cleanupDaemonThreads=false >> test-behavior-results.txt

echo
echo "Sending queries for joe and john to test_cb_2"
echo
mvn exec:java -Dexec.mainClass="QueriesClientExample" -Dexec.args="$host $engine_2 data/2-user-query.json" -Dexec.cleanupDaemonThreads=false >> test-behavior-results.txt


echo "---------------------- profile query differences should only be timing ----------------------------"
diff test-profile-results.txt data/expected-test-profile-results.txt | grep Results
echo
echo "---------------------- behavior differences should only be timing ----------------------------"
diff test-behavior-results.txt data/expected-test-behavior-results.txt | grep Results
echo

if [ "$clean_test_artifacts" == true ]; then
    harness delete $engine_1
    harness delete $engine_2
fi

cd ..
