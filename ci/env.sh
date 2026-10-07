# Sourced by the other ci/*.sh scripts, from the repository root.
# Provides what make.sh gets from `swipl --dump-runtime-variables`, plus
# SWIPL, which is `swipl` with the sbcl search path (ci/init.pl).

eval "$(swipl --dump-runtime-variables)"
export PLBASE PLLIBDIR PLLIB

ARCH=$(uname -s)
PLU_ROOT=$(pwd)
PLU_STAGE=$PLU_ROOT/build/stage
SWIPL="swipl -f $PLU_ROOT/ci/init.pl"
export ARCH PLU_ROOT PLU_STAGE SWIPL
