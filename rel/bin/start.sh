#!/bin/sh

set -o errexit
set -o xtrace

bin/td_qx eval 'Elixir.TdQx.Release.migrate()'
bin/td_qx start
