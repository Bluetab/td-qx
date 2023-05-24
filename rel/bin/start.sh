#!/bin/sh

set -o errexit
set -o xtrace

export PHX_SERVER=true

bin/td_qx eval 'Elixir.TdQx.Release.migrate()'
bin/td_qx start
