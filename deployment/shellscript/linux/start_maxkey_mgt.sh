#!/bin/bash
source ./set_maxkey_env.sh

JAVA_MARK=MaxKeyMgtBoot
JAVA_OPTS=" -Xms256m "
JAVA_OPTS="${JAVA_OPTS} -Xmx2048m"
JAVA_OPTS="${JAVA_OPTS} -Dfile.encoding=UTF-8"
JAVA_OPTS="${JAVA_OPTS} -DjavaMark=${JAVA_MARK}"

JAVA_CONF=./maxkey_mgt
JAVA_LIBMAXKEYPATH=./maxkey_mgt
JAVA_CLASSPATH=./classes:./bin:$JAVA_CONF:
JAVA_MAINCLASS=org.dromara.maxkey.MaxKeyMgtApplication
JAVA_EXEC=$JAVA_HOME/bin/java

export JAVA_CLASSPATH
export JAVA_LIBPATH
export JAVA_LIBMAXKEYPATH
              
# 定位可执行 jar（优先 bootJar 产物，避免多 jar 时取错）
JAVA_CLASSPATH=$(ls -1 $JAVA_LIBMAXKEYPATH/maxkey-mgt-boot-*.jar 2>/dev/null | head -1)
[ -z "$JAVA_CLASSPATH" ] && JAVA_CLASSPATH=$(ls -1 $JAVA_LIBMAXKEYPATH/*.jar 2>/dev/null | head -1)
if [ -z "$JAVA_CLASSPATH" ]; then
        echo "ERROR: no jar found under $JAVA_LIBMAXKEYPATH"
        exit 1
fi

export JAVA_CLASSPATH
# Display our environment
echo "-------------------------------------------------------------------------------"
echo "  Bootstrap Environment"
echo ""
echo JAVA_CLASSPATH :  ${JAVA_CLASSPATH}
echo JAVA_CONF      :  $JAVA_CONF
echo JAVA_OPTS      :  $JAVA_OPTS
echo JAVA_HOME      :  $JAVA_HOME  
echo JAVA           :  $JAVA_EXEC
${JAVA_EXEC} -version
echo ""
echo "-------------------------------------------------------------------------------"
echo ""

# 日志目录不存在时重定向会失败，进程根本起不来
mkdir -p ./logs

nohup $JAVA_EXEC -jar $JAVA_OPTS $JAVA_CLASSPATH  >./logs/nohup_mgt.out 2>&1 &

echo MaxKeyMgt is starting，you can check the ./logs/nohup_mgt.out
