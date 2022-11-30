#!/usr/bin/env groovy

library("govuk")

node {
  govuk.setEnvar("TEST_DATABASE_URL", "postgresql://postgres@127.0.0.1:54313/account-api-test")
  govuk.buildProject(
    // Run rake default tasks except for pact:verify as that is ran via
    // a separate GitHub action.
    overrideTestTask: { sh("bundle exec rake lint spec") }
  )
}
