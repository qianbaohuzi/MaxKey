#!/bin/bash
echo "-------------------------------------------------------------------------------"
echo "--    Maxkey Sigle Sign On  System                                           --"
echo "--    Set JAVA_HOME  ....                                                    --"
echo "--    JAVA_HOME   JDK                                                        --"

# 优先使用外部传入的 JAVA_HOME，否则使用发布包内自带的 JDK 21
# 注意：MaxKey 4.2.0 字节码为 Java 21（class file major 65），JDK 必须 >= 21
JAVA_HOME=${JAVA_HOME:-./jdk-21}

$JAVA_HOME/bin/java -version

echo "--    JAVA_HOME  $JAVA_HOME "
echo "-------------------------------------------------------------------------------"