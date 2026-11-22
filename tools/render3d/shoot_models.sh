#!/bin/bash
# Usage: tools/render3d/shoot_models.sh <out dir> <group,group,...>   -> <out dir>/<group>_<cam>.png (4 cameras each)
set -e
D=$1; G=$2
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
mkdir -p $D
if [ ! -f $D/three.min.js ]; then (cd $D && npm pack three@0.160.0 >/dev/null 2>&1 && tar xzf three-0.160.0.tgz && cp package/build/three.min.js .); fi
cp $ROOT/tools/render3d/view.html $D/
cat $ROOT/tools/render3d/models.lua $ROOT/tools/render3d/scenario_models.lua > $D/_scenario.lua
(cd $ROOT && SCENARIO_ARGS=$G OUT_DIR=$D python3 tools/run_mock.py ${API:-api_classes.lua} $D/_scenario.lua | grep -E "exported|RESULT|rror" )
n=0; IDX=""
for g in ${G//,/ }; do n=$((n+1)); (printf 'window.SCENE='; cat $D/scene$n.json; printf ';') > $D/scene$n.js; IDX="$IDX,$n"; done
NOPANEL=1 node $ROOT/tools/render3d/shoot.js $D ${IDX#,} 0,1,2,3
n=0
for g in ${G//,/ }; do n=$((n+1)); for c in 0 1 2 3; do mv $D/shot_${n}_$c.png $D/${g}_$c.png; done; done
