-- MaxKey 4.2.0 KingbaseES 最小种子库脚本
-- 由 sql/kingbase/make-seed.py 从 maxkey.sql 裁剪生成，请勿手工修改
--
-- 与完整版的差异：
--   表结构 **完全一致**（44 张表、全部索引/约束/注释/序列），不做任何删减。
--   INSERT 只保留登录与管理端菜单的最小闭环：
--     * mxk_userinfo 仅 admin 一行（完整版有 60 个演示用户，共 16MB 头像）
--     * mxk_apps 保留 34 个演示应用的**配置**，icon 字段置 NULL（省 1.5MB）
--     * 演示登录历史 / 系统日志 / 同步记录类全部丢弃
--
-- 建库：
--   ksql -U maxkey -d maxkey -f maxkey-seed.sql
--
-- 初始账号：admin / maxkey   （mxk_userinfo.password 为 {plain}maxkey）
-- 上线前请立即：① 改 admin 密码  ② 把 mxk_institutions.domain 改成真实域名

-- MaxKey 4.2.0 KingbaseES 初始化脚本
-- 由 sql/kingbase/convert_from_mysql.py 自动生成，请勿手工修改
-- 源文件: sql/v4.2.0/maxkey.sql

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

DROP TABLE IF EXISTS mxk_access CASCADE;
CREATE TABLE mxk_access (
    id varchar(45) NOT NULL,
    groupid varchar(45) NOT NULL,
    appid varchar(45) NOT NULL,
    createddate timestamp DEFAULT CURRENT_TIMESTAMP,
    instid varchar(45) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT groupid_appid UNIQUE (groupid, appid)
);
COMMENT ON COLUMN mxk_access.id IS E'ID';
COMMENT ON COLUMN mxk_access.groupid IS E'GROUPID';
COMMENT ON COLUMN mxk_access.appid IS E'APPID';
DROP TABLE IF EXISTS mxk_accounts CASCADE;
CREATE TABLE mxk_accounts (
    id varchar(45) NOT NULL,
    userid varchar(45) DEFAULT NULL,
    username varchar(45) DEFAULT NULL,
    displayname varchar(45) DEFAULT NULL,
    strategyname varchar(200) DEFAULT NULL,
    strategyid varchar(45) DEFAULT NULL,
    appid varchar(45) DEFAULT NULL,
    appname varchar(100) DEFAULT NULL,
    relatedusername varchar(200) DEFAULT NULL,
    relatedpassword varchar(500) DEFAULT NULL,
    createtype varchar(45) DEFAULT 'automatic',
    status integer DEFAULT NULL,
    createdby varchar(45) DEFAULT NULL,
    createddate timestamp DEFAULT CURRENT_TIMESTAMP,
    modifiedby varchar(45) DEFAULT NULL,
    modifieddate timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    instid varchar(45) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT unique_user_account UNIQUE (username, appid, relatedusername, userid)
);
COMMENT ON TABLE mxk_accounts IS E'用户账号表';
COMMENT ON COLUMN mxk_accounts.id IS E'主键';
COMMENT ON COLUMN mxk_accounts.userid IS E'用户ID';
COMMENT ON COLUMN mxk_accounts.username IS E'用户名';
COMMENT ON COLUMN mxk_accounts.displayname IS E'用户显示名';
COMMENT ON COLUMN mxk_accounts.appid IS E'应用ID';
COMMENT ON COLUMN mxk_accounts.appname IS E'应用名称';
COMMENT ON COLUMN mxk_accounts.relatedusername IS E'用户名';
COMMENT ON COLUMN mxk_accounts.relatedpassword IS E'密码';
COMMENT ON COLUMN mxk_accounts.modifieddate IS E'修改时间';
DROP TABLE IF EXISTS mxk_apps CASCADE;
CREATE TABLE mxk_apps (
    id varchar(45) NOT NULL,
    appname varchar(300) NOT NULL,
    loginurl varchar(300) NOT NULL,
    category varchar(45) DEFAULT NULL,
    secret varchar(500) DEFAULT NULL,
    protocol varchar(300) DEFAULT NULL,
    icon bytea,
    status smallint DEFAULT NULL,
    createdby varchar(45) DEFAULT NULL,
    createddate timestamp DEFAULT CURRENT_TIMESTAMP,
    modifiedby varchar(45) DEFAULT NULL,
    modifieddate timestamp DEFAULT NULL,
    description varchar(400) DEFAULT NULL,
    vendor varchar(45) DEFAULT NULL,
    vendorurl varchar(200) DEFAULT NULL,
    credential varchar(45) DEFAULT 'none',
    sharedusername varchar(100) DEFAULT NULL,
    sharedpassword varchar(500) DEFAULT NULL,
    systemuserattr varchar(45) DEFAULT NULL,
    isextendattr varchar(4) DEFAULT NULL,
    extendattr varchar(4000) DEFAULT NULL,
    sortindex integer DEFAULT '0',
    issignature smallint DEFAULT '0',
    visible smallint DEFAULT '0',
    isadapter smallint DEFAULT '0',
    adapterid varchar(45) DEFAULT NULL,
    adaptername varchar(100) DEFAULT NULL,
    adapter varchar(500) DEFAULT NULL,
    principal varchar(45) DEFAULT NULL,
    credentials varchar(500) DEFAULT NULL,
    userpropertys varchar(4000) DEFAULT NULL,
    inducer varchar(50) DEFAULT 'IDP',
    logouturl varchar(300) DEFAULT NULL,
    logouttype integer DEFAULT NULL,
    instid varchar(45) NOT NULL,
    frequently varchar(45) DEFAULT 'no',
    resourcemgt varchar(10) DEFAULT 'n',
    openapiright varchar(10) DEFAULT 'read',
    PRIMARY KEY (id)
);
COMMENT ON TABLE mxk_apps IS E'应用表';
COMMENT ON COLUMN mxk_apps.id IS E'主键';
COMMENT ON COLUMN mxk_apps.appname IS E'应用名称';
COMMENT ON COLUMN mxk_apps.loginurl IS E'应用登录地址';
COMMENT ON COLUMN mxk_apps.category IS E'应用类型';
COMMENT ON COLUMN mxk_apps.secret IS E'应用密钥';
COMMENT ON COLUMN mxk_apps.protocol IS E'单点登录协议';
COMMENT ON COLUMN mxk_apps.icon IS E'应用图标';
COMMENT ON COLUMN mxk_apps.status IS E'状态';
COMMENT ON COLUMN mxk_apps.createdby IS E'创建人';
COMMENT ON COLUMN mxk_apps.createddate IS E'创建时间';
COMMENT ON COLUMN mxk_apps.modifiedby IS E'修改人';
COMMENT ON COLUMN mxk_apps.modifieddate IS E'修改时间';
COMMENT ON COLUMN mxk_apps.description IS E'描述';
COMMENT ON COLUMN mxk_apps.vendor IS E'供应商';
COMMENT ON COLUMN mxk_apps.vendorurl IS E'供应商地址';
COMMENT ON COLUMN mxk_apps.credential IS E'单点登录凭证类型';
COMMENT ON COLUMN mxk_apps.sharedusername IS E'共享用户名';
COMMENT ON COLUMN mxk_apps.sharedpassword IS E'共享密码';
COMMENT ON COLUMN mxk_apps.systemuserattr IS E'系统用户属性';
COMMENT ON COLUMN mxk_apps.isextendattr IS E'是否支持应用扩展属性';
COMMENT ON COLUMN mxk_apps.extendattr IS E'应用扩展属性';
COMMENT ON COLUMN mxk_apps.sortindex IS E'排序序号';
COMMENT ON COLUMN mxk_apps.issignature IS E'签名状态';
COMMENT ON COLUMN mxk_apps.visible IS E'可见标识';
COMMENT ON COLUMN mxk_apps.isadapter IS E'是否支持适配器';
COMMENT ON COLUMN mxk_apps.adapter IS E'适配器';
COMMENT ON COLUMN mxk_apps.principal IS E'接口API用户';
COMMENT ON COLUMN mxk_apps.credentials IS E'接口API用户凭证';
COMMENT ON COLUMN mxk_apps.userpropertys IS E'接口返回用户属性定义';
COMMENT ON COLUMN mxk_apps.inducer IS E'引导方式';
COMMENT ON COLUMN mxk_apps.logouturl IS E'注销地址';
COMMENT ON COLUMN mxk_apps.logouttype IS E'单点注销方式 0 NONE,1 BACK_CHANNEL,2 FRONT_CHANNEL';
DROP TABLE IF EXISTS mxk_apps_adapters CASCADE;
CREATE TABLE mxk_apps_adapters (
    id varchar(50) NOT NULL,
    name varchar(100) DEFAULT NULL,
    protocol varchar(300) DEFAULT NULL,
    adapter varchar(500) DEFAULT NULL,
    sortindex integer DEFAULT NULL,
    createdby varchar(45) DEFAULT NULL,
    createddate timestamp DEFAULT CURRENT_TIMESTAMP,
    modifiedby varchar(45) DEFAULT NULL,
    modifieddate timestamp DEFAULT NULL,
    description varchar(500) DEFAULT NULL,
    PRIMARY KEY (id)
);
COMMENT ON TABLE mxk_apps_adapters IS E'ADAPTER';
DROP TABLE IF EXISTS mxk_apps_cas_details CASCADE;
CREATE TABLE mxk_apps_cas_details (
    id varchar(45) NOT NULL,
    service varchar(400) NOT NULL,
    callbackurl varchar(400) NOT NULL,
    expires integer DEFAULT NULL,
    instid varchar(45) NOT NULL,
    casuser varchar(45) DEFAULT NULL,
    PRIMARY KEY (id)
);
DROP TABLE IF EXISTS mxk_apps_form_based_details CASCADE;
CREATE TABLE mxk_apps_form_based_details (
    id varchar(45) NOT NULL,
    usernamemapping varchar(45) DEFAULT NULL,
    passwordmapping varchar(45) DEFAULT NULL,
    redirecturi varchar(400) DEFAULT NULL,
    authorizeview varchar(100) DEFAULT NULL,
    passwordalgorithm varchar(45) DEFAULT NULL,
    instid varchar(45) NOT NULL,
    PRIMARY KEY (id)
);
COMMENT ON TABLE mxk_apps_form_based_details IS E'FormBase details';
COMMENT ON COLUMN mxk_apps_form_based_details.id IS E'ID';
COMMENT ON COLUMN mxk_apps_form_based_details.usernamemapping IS E'FORM LOGIN NAME';
COMMENT ON COLUMN mxk_apps_form_based_details.passwordmapping IS E'FORM LOGIN PASSWORD';
COMMENT ON COLUMN mxk_apps_form_based_details.redirecturi IS E'REDIRECTURI';
COMMENT ON COLUMN mxk_apps_form_based_details.authorizeview IS E'AUTHORIZEVIEW FOR LOCAL VIEW DEAL';
DROP TABLE IF EXISTS mxk_apps_jwt_details CASCADE;
CREATE TABLE mxk_apps_jwt_details (
    id varchar(45) NOT NULL,
    issuer varchar(200) DEFAULT NULL,
    subject varchar(100) DEFAULT NULL,
    audience varchar(200) DEFAULT NULL,
    algorithmkey text NOT NULL,
    algorithm varchar(45) NOT NULL,
    encryptionmethod varchar(45) DEFAULT NULL,
    signature varchar(45) DEFAULT NULL,
    signaturekey text,
    expires integer DEFAULT '0',
    redirecturi varchar(400) NOT NULL,
    jwtname varchar(45) DEFAULT NULL,
    tokentype varchar(20) DEFAULT NULL,
    instid varchar(45) NOT NULL,
    PRIMARY KEY (id)
);
COMMENT ON COLUMN mxk_apps_jwt_details.id IS E'ID';
COMMENT ON COLUMN mxk_apps_jwt_details.algorithmkey IS E'秘钥';
COMMENT ON COLUMN mxk_apps_jwt_details.algorithm IS E'加密算法';
COMMENT ON COLUMN mxk_apps_jwt_details.signature IS E'签名算法';
COMMENT ON COLUMN mxk_apps_jwt_details.signaturekey IS E'签名密钥';
COMMENT ON COLUMN mxk_apps_jwt_details.expires IS E'EXPIRES TIME';
COMMENT ON COLUMN mxk_apps_jwt_details.redirecturi IS E'REDIRECTURI';
DROP TABLE IF EXISTS mxk_apps_oauth_client_details CASCADE;
CREATE TABLE mxk_apps_oauth_client_details (
    client_id varchar(45) NOT NULL,
    resource_ids varchar(256) DEFAULT NULL,
    client_secret varchar(500) DEFAULT NULL,
    scope varchar(256) DEFAULT NULL,
    authorized_grant_types varchar(256) DEFAULT NULL,
    web_server_redirect_uri varchar(512) DEFAULT NULL,
    authorities varchar(256) DEFAULT NULL,
    access_token_validity integer DEFAULT NULL,
    refresh_token_validity integer DEFAULT NULL,
    additional_information varchar(4096) DEFAULT NULL,
    approvalprompt varchar(45) DEFAULT 'force',
    autoapprove varchar(256) DEFAULT NULL,
    pkce varchar(45) DEFAULT NULL,
    protocol varchar(45) DEFAULT NULL,
    instid varchar(45) NOT NULL,
    issuer varchar(200) DEFAULT NULL,
    audience varchar(200) DEFAULT NULL,
    algorithmkey text,
    algorithm varchar(45) DEFAULT NULL,
    encryptionmethod varchar(45) DEFAULT NULL,
    signature varchar(45) DEFAULT NULL,
    signaturekey text,
    userinforesponse varchar(45) DEFAULT 'Normal',
    subject varchar(45) DEFAULT 'username',
    PRIMARY KEY (client_id)
);
COMMENT ON TABLE mxk_apps_oauth_client_details IS E'oauth_client_details';
COMMENT ON COLUMN mxk_apps_oauth_client_details.client_id IS E'appkey';
COMMENT ON COLUMN mxk_apps_oauth_client_details.resource_ids IS E'资源ids';
COMMENT ON COLUMN mxk_apps_oauth_client_details.client_secret IS E'appsecret';
COMMENT ON COLUMN mxk_apps_oauth_client_details.scope IS E'SCOPE';
COMMENT ON COLUMN mxk_apps_oauth_client_details.authorized_grant_types IS E'授权类型';
COMMENT ON COLUMN mxk_apps_oauth_client_details.web_server_redirect_uri IS E'REDIRECT_URI认证返回地址';
COMMENT ON COLUMN mxk_apps_oauth_client_details.authorities IS E'AUTHORITIES';
COMMENT ON COLUMN mxk_apps_oauth_client_details.access_token_validity IS E'accesstoken有效时间';
COMMENT ON COLUMN mxk_apps_oauth_client_details.autoapprove IS E'自动通过';
COMMENT ON COLUMN mxk_apps_oauth_client_details.userinforesponse IS E'normal,signing,encryption, If both signing and encryption are performed, it MUST be signed then encrypted';
DROP TABLE IF EXISTS mxk_apps_saml_v20_details CASCADE;
CREATE TABLE mxk_apps_saml_v20_details (
    id varchar(45) NOT NULL,
    certissuer varchar(200) DEFAULT NULL,
    certsubject varchar(200) DEFAULT NULL,
    certexpiration varchar(100) DEFAULT NULL,
    keystore bytea,
    spacsurl varchar(200) NOT NULL,
    issuer varchar(300) DEFAULT NULL,
    entityid varchar(300) DEFAULT NULL,
    validityinterval integer DEFAULT NULL,
    nameidformat varchar(45) DEFAULT NULL,
    nameidconvert varchar(45) DEFAULT NULL,
    nameidsuffix varchar(150) DEFAULT NULL,
    audience varchar(300) DEFAULT NULL,
    encrypted varchar(45) DEFAULT NULL,
    binding varchar(45) DEFAULT NULL,
    signature varchar(45) DEFAULT NULL,
    digestmethod varchar(45) DEFAULT NULL,
    metaurl varchar(500) DEFAULT NULL,
    instid varchar(45) NOT NULL,
    PRIMARY KEY (id)
);
DROP TABLE IF EXISTS mxk_apps_token_based_details CASCADE;
CREATE TABLE mxk_apps_token_based_details (
    id varchar(45) NOT NULL,
    algorithmkey varchar(500) NOT NULL,
    algorithm varchar(45) NOT NULL,
    expires integer DEFAULT '0',
    redirecturi varchar(400) NOT NULL,
    cookiename varchar(45) DEFAULT NULL,
    tokentype varchar(20) DEFAULT NULL,
    instid varchar(45) NOT NULL,
    PRIMARY KEY (id)
);
COMMENT ON COLUMN mxk_apps_token_based_details.id IS E'ID';
COMMENT ON COLUMN mxk_apps_token_based_details.algorithmkey IS E'秘钥';
COMMENT ON COLUMN mxk_apps_token_based_details.algorithm IS E'加密算法 /DES,DESede,Blowfish and AES';
COMMENT ON COLUMN mxk_apps_token_based_details.expires IS E'EXPIRES TIME';
COMMENT ON COLUMN mxk_apps_token_based_details.redirecturi IS E'REDIRECTURI';
DROP TABLE IF EXISTS mxk_cnf_email_senders CASCADE;
CREATE TABLE mxk_cnf_email_senders (
    id varchar(50) NOT NULL,
    smtphost varchar(45) DEFAULT NULL,
    port integer DEFAULT NULL,
    account varchar(45) DEFAULT NULL,
    credentials varchar(500) DEFAULT NULL,
    sslswitch integer DEFAULT NULL,
    sender varchar(45) DEFAULT NULL,
    protocol varchar(45) DEFAULT NULL,
    encoding varchar(45) DEFAULT NULL,
    status integer DEFAULT NULL,
    instid varchar(45) DEFAULT NULL,
    description varchar(45) DEFAULT NULL,
    createdby varchar(45) DEFAULT NULL,
    createddate timestamp DEFAULT CURRENT_TIMESTAMP,
    modifiedby varchar(45) DEFAULT NULL,
    modifieddate timestamp DEFAULT NULL,
    PRIMARY KEY (id)
);
DROP TABLE IF EXISTS mxk_cnf_ldap_context CASCADE;
CREATE TABLE mxk_cnf_ldap_context (
    id varchar(50) NOT NULL,
    product varchar(45) DEFAULT NULL,
    sslswitch varchar(45) DEFAULT NULL,
    providerurl varchar(200) DEFAULT NULL,
    principal varchar(100) DEFAULT NULL,
    credentials varchar(500) DEFAULT NULL,
    basedn varchar(500) DEFAULT NULL,
    filters varchar(500) DEFAULT NULL,
    truststore varchar(500) DEFAULT NULL,
    truststorepassword varchar(100) DEFAULT NULL,
    msaddomain varchar(100) DEFAULT NULL,
    accountmapping varchar(45) DEFAULT 'YES',
    status integer DEFAULT NULL,
    description varchar(500) DEFAULT NULL,
    instid varchar(45) DEFAULT NULL,
    createdby varchar(45) DEFAULT NULL,
    createddate timestamp DEFAULT CURRENT_TIMESTAMP,
    modifiedby varchar(45) DEFAULT NULL,
    modifieddate timestamp DEFAULT NULL,
    PRIMARY KEY (id)
);
DROP TABLE IF EXISTS mxk_cnf_password_policy CASCADE;
CREATE TABLE mxk_cnf_password_policy (
    id varchar(45) NOT NULL,
    minlength smallint DEFAULT '0',
    maxlength smallint DEFAULT '0',
    lowercase smallint DEFAULT '0',
    uppercase smallint DEFAULT '0',
    digits smallint DEFAULT '0',
    specialchar smallint DEFAULT '0',
    attempts smallint DEFAULT '0',
    duration smallint DEFAULT '0',
    expiration smallint DEFAULT '0',
    username smallint DEFAULT '0',
    history smallint DEFAULT '0',
    dictionary smallint DEFAULT NULL,
    alphabetical smallint DEFAULT NULL,
    numerical smallint DEFAULT NULL,
    qwerty smallint DEFAULT NULL,
    occurances smallint DEFAULT NULL,
    createdby varchar(45) DEFAULT NULL,
    createddate timestamp DEFAULT CURRENT_TIMESTAMP,
    modifiedby varchar(45) DEFAULT NULL,
    modifieddate timestamp DEFAULT NULL,
    PRIMARY KEY (id)
);
COMMENT ON TABLE mxk_cnf_password_policy IS E'password policy';
COMMENT ON COLUMN mxk_cnf_password_policy.minlength IS E'MINLENGTH';
COMMENT ON COLUMN mxk_cnf_password_policy.maxlength IS E'MAXLENGTH';
COMMENT ON COLUMN mxk_cnf_password_policy.lowercase IS E'LOWERCASE';
COMMENT ON COLUMN mxk_cnf_password_policy.uppercase IS E'UPPERCASE';
COMMENT ON COLUMN mxk_cnf_password_policy.digits IS E'DIGITS';
COMMENT ON COLUMN mxk_cnf_password_policy.specialchar IS E'SPECIALCHAR';
COMMENT ON COLUMN mxk_cnf_password_policy.attempts IS E'ATTEMPTS LOGIN FOR LOCK';
COMMENT ON COLUMN mxk_cnf_password_policy.duration IS E'DURATION ';
COMMENT ON COLUMN mxk_cnf_password_policy.expiration IS E'PASSWORD EXPIRATION';
COMMENT ON COLUMN mxk_cnf_password_policy.username IS E'USERNAME IN PASSWORD';
COMMENT ON COLUMN mxk_cnf_password_policy.history IS E'SIMPLEPASSWORDS NOT USE FOR PASSWORD';
COMMENT ON COLUMN mxk_cnf_password_policy.createdby IS E'CREATEDBY';
COMMENT ON COLUMN mxk_cnf_password_policy.createddate IS E'CREATEDDATE';
COMMENT ON COLUMN mxk_cnf_password_policy.modifiedby IS E'MODIFIEDBY';
COMMENT ON COLUMN mxk_cnf_password_policy.modifieddate IS E'MODIFIEDDATE';
DROP TABLE IF EXISTS mxk_cnf_sms_provider CASCADE;
CREATE TABLE mxk_cnf_sms_provider (
    id varchar(50) NOT NULL,
    provider varchar(100) DEFAULT NULL,
    providername varchar(45) DEFAULT NULL,
    message varchar(500) DEFAULT NULL,
    appkey varchar(100) DEFAULT NULL,
    appsecret varchar(500) DEFAULT NULL,
    templateid varchar(45) DEFAULT NULL,
    signname varchar(45) DEFAULT NULL,
    smssdkappid varchar(45) DEFAULT NULL,
    status integer DEFAULT NULL,
    description varchar(500) DEFAULT NULL,
    instid varchar(45) DEFAULT NULL,
    createdby varchar(45) DEFAULT NULL,
    createddate timestamp DEFAULT CURRENT_TIMESTAMP,
    modifiedby varchar(45) DEFAULT NULL,
    modifieddate timestamp DEFAULT NULL,
    PRIMARY KEY (id)
);
COMMENT ON COLUMN mxk_cnf_sms_provider.smssdkappid IS E'tencentcloud smssdkappid';
DROP TABLE IF EXISTS mxk_connectors CASCADE;
CREATE TABLE mxk_connectors (
    id varchar(50) NOT NULL,
    connname varchar(200) DEFAULT NULL,
    justintime smallint DEFAULT NULL,
    scheduler varchar(45) DEFAULT NULL,
    providerurl varchar(400) DEFAULT NULL,
    principal varchar(200) DEFAULT NULL,
    credentials varchar(500) DEFAULT NULL,
    filters varchar(400) DEFAULT NULL,
    status varchar(45) DEFAULT NULL,
    createdby varchar(45) DEFAULT NULL,
    createddate timestamp DEFAULT CURRENT_TIMESTAMP,
    modifiedby varchar(45) DEFAULT NULL,
    modifieddate timestamp DEFAULT NULL,
    description varchar(45) DEFAULT NULL,
    instid varchar(45) NOT NULL,
    appid varchar(45) DEFAULT NULL,
    appname varchar(45) DEFAULT NULL,
    PRIMARY KEY (id)
);
COMMENT ON TABLE mxk_connectors IS E'连接器';
DROP TABLE IF EXISTS mxk_file_upload CASCADE;
CREATE TABLE mxk_file_upload (
    id varchar(100) NOT NULL,
    filename varchar(400) DEFAULT NULL,
    uploaded bytea NOT NULL,
    contentsize integer DEFAULT NULL,
    contenttype varchar(100) DEFAULT NULL,
    createdby varchar(45) DEFAULT NULL,
    createddate timestamp DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
);
DROP TABLE IF EXISTS mxk_group_member CASCADE;
CREATE TABLE mxk_group_member (
    id varchar(100) NOT NULL DEFAULT '',
    groupid varchar(100) NOT NULL,
    memberid varchar(100) NOT NULL,
    type varchar(45) NOT NULL,
    createddate timestamp DEFAULT CURRENT_TIMESTAMP,
    instid varchar(45) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT groupid_memberid UNIQUE (groupid, memberid, type)
);
COMMENT ON COLUMN mxk_group_member.id IS E'ID';
COMMENT ON COLUMN mxk_group_member.groupid IS E'GROUPID';
COMMENT ON COLUMN mxk_group_member.memberid IS E'MEMBERID USERID OR GROUP ID';
COMMENT ON COLUMN mxk_group_member.type IS E'TYPE  USER OR GROUP';
DROP TABLE IF EXISTS mxk_groups CASCADE;
CREATE TABLE mxk_groups (
    id varchar(45) NOT NULL,
    groupcode varchar(45) DEFAULT NULL,
    groupname varchar(100) DEFAULT NULL,
    category varchar(20) DEFAULT NULL,
    filters text,
    orgidslist text,
    resumetime varchar(45) DEFAULT NULL,
    suspendtime varchar(45) DEFAULT NULL,
    status smallint DEFAULT NULL,
    createdby varchar(45) DEFAULT NULL,
    isdefault smallint DEFAULT NULL,
    createddate timestamp DEFAULT CURRENT_TIMESTAMP,
    modifiedby varchar(45) DEFAULT NULL,
    modifieddate timestamp DEFAULT NULL,
    description varchar(500) DEFAULT NULL,
    instid varchar(45) NOT NULL
);
COMMENT ON COLUMN mxk_groups.id IS E'ID';
COMMENT ON COLUMN mxk_groups.groupname IS E'GROUP NAME';
COMMENT ON COLUMN mxk_groups.category IS E'动态用户组，dynamic动态组 static静态组app应用账号组';
COMMENT ON COLUMN mxk_groups.filters IS E'过滤条件SQL';
COMMENT ON COLUMN mxk_groups.orgidslist IS E'机构列表';
COMMENT ON COLUMN mxk_groups.resumetime IS E'RESUMETIME';
COMMENT ON COLUMN mxk_groups.suspendtime IS E'SUSPENDTIME';
COMMENT ON COLUMN mxk_groups.status IS E'STATUS';
COMMENT ON COLUMN mxk_groups.createdby IS E'CREATEDBY';
COMMENT ON COLUMN mxk_groups.isdefault IS E'ISDEFAULT';
COMMENT ON COLUMN mxk_groups.createddate IS E'CREATEDDATE';
COMMENT ON COLUMN mxk_groups.modifiedby IS E'MODIFIEDBY';
COMMENT ON COLUMN mxk_groups.modifieddate IS E'MODIFIEDDATE';
COMMENT ON COLUMN mxk_groups.description IS E'DESCRIPTION';
DROP TABLE IF EXISTS mxk_history_connector CASCADE;
CREATE TABLE mxk_history_connector (
    id varchar(45) NOT NULL,
    conname varchar(200) DEFAULT NULL,
    sourceid varchar(45) DEFAULT NULL,
    sourcename varchar(500) DEFAULT NULL,
    objectid varchar(45) DEFAULT NULL,
    objectname varchar(500) DEFAULT NULL,
    description varchar(1000) DEFAULT NULL,
    synctime timestamp DEFAULT CURRENT_TIMESTAMP,
    result varchar(45) DEFAULT NULL,
    instid varchar(45) NOT NULL,
    topic varchar(45) DEFAULT NULL,
    actiontype varchar(45) DEFAULT NULL,
    PRIMARY KEY (id)
);
DROP TABLE IF EXISTS mxk_history_event CASCADE;
CREATE TABLE mxk_history_event (
    id bigint GENERATED BY DEFAULT AS IDENTITY,
    eventname varchar(45) DEFAULT NULL,
    datatype varchar(45) DEFAULT NULL,
    datacount integer DEFAULT NULL,
    executedatetime timestamp DEFAULT CURRENT_TIMESTAMP,
    instid varchar(45) NOT NULL,
    PRIMARY KEY (id)
);
DROP TABLE IF EXISTS mxk_history_login CASCADE;
CREATE TABLE mxk_history_login (
    id varchar(45) NOT NULL,
    category smallint DEFAULT '1',
    sessionid varchar(45) DEFAULT NULL,
    userid varchar(45) NOT NULL,
    username varchar(200) NOT NULL,
    displayname varchar(45) DEFAULT NULL,
    message varchar(200) DEFAULT NULL,
    sourceip varchar(300) DEFAULT NULL,
    country varchar(100) DEFAULT NULL,
    province varchar(100) DEFAULT NULL,
    city varchar(100) DEFAULT NULL,
    location varchar(500) DEFAULT NULL,
    logintype varchar(45) DEFAULT NULL,
    code varchar(45) DEFAULT NULL,
    provider varchar(45) DEFAULT NULL,
    browser varchar(45) DEFAULT NULL,
    platform varchar(45) DEFAULT NULL,
    application varchar(45) DEFAULT NULL,
    loginurl varchar(450) DEFAULT NULL,
    logintime timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    logouttime timestamp NOT NULL DEFAULT '1970-01-01 00:00:00',
    sessionstatus integer DEFAULT '1',
    instid varchar(45) DEFAULT NULL,
    PRIMARY KEY (id)
);
COMMENT ON TABLE mxk_history_login IS E'history_login';
COMMENT ON COLUMN mxk_history_login.id IS E'ID';
COMMENT ON COLUMN mxk_history_login.sessionid IS E'SESSIONID';
COMMENT ON COLUMN mxk_history_login.userid IS E'USERID';
COMMENT ON COLUMN mxk_history_login.username IS E'USERNAME';
COMMENT ON COLUMN mxk_history_login.displayname IS E'DISPLAYNAME';
COMMENT ON COLUMN mxk_history_login.message IS E'MESSAGE';
COMMENT ON COLUMN mxk_history_login.sourceip IS E'LOGIN SOURCEIP ';
COMMENT ON COLUMN mxk_history_login.logintype IS E'LOGINTYPE';
COMMENT ON COLUMN mxk_history_login.code IS E'CODE';
COMMENT ON COLUMN mxk_history_login.provider IS E'PROVIDER';
COMMENT ON COLUMN mxk_history_login.browser IS E'BROWSER';
COMMENT ON COLUMN mxk_history_login.platform IS E'PLATFORM';
COMMENT ON COLUMN mxk_history_login.application IS E'APPLICATION';
COMMENT ON COLUMN mxk_history_login.loginurl IS E'LOGINURL';
COMMENT ON COLUMN mxk_history_login.logintime IS E'LOGINTIME';
COMMENT ON COLUMN mxk_history_login.logouttime IS E'LOGOUTTIME';
DROP TABLE IF EXISTS mxk_history_login_apps CASCADE;
CREATE TABLE mxk_history_login_apps (
    id varchar(45) NOT NULL,
    sessionid varchar(45) DEFAULT NULL,
    logintime timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    appid varchar(45) NOT NULL,
    appname varchar(45) DEFAULT NULL,
    userid varchar(45) DEFAULT NULL,
    username varchar(45) DEFAULT NULL,
    displayname varchar(45) DEFAULT NULL,
    instid varchar(45) NOT NULL,
    PRIMARY KEY (id)
);
COMMENT ON TABLE mxk_history_login_apps IS E'Sign On apps Records';
COMMENT ON COLUMN mxk_history_login_apps.id IS E'ID';
COMMENT ON COLUMN mxk_history_login_apps.sessionid IS E'SESSIONID';
COMMENT ON COLUMN mxk_history_login_apps.logintime IS E'LOGINTIME';
COMMENT ON COLUMN mxk_history_login_apps.appid IS E'ACCESS APPID';
COMMENT ON COLUMN mxk_history_login_apps.appname IS E'APPNAME';
COMMENT ON COLUMN mxk_history_login_apps.userid IS E'USERID';
COMMENT ON COLUMN mxk_history_login_apps.username IS E'USERNAME';
COMMENT ON COLUMN mxk_history_login_apps.displayname IS E'DISPLAYNAME';
DROP TABLE IF EXISTS mxk_history_provisions CASCADE;
CREATE TABLE mxk_history_provisions (
    id varchar(50) NOT NULL,
    topic varchar(45) DEFAULT NULL,
    actiontype varchar(45) DEFAULT NULL,
    content text,
    sendtime timestamp DEFAULT CURRENT_TIMESTAMP,
    connected smallint DEFAULT NULL,
    instid integer DEFAULT NULL,
    PRIMARY KEY (id)
);
DROP TABLE IF EXISTS mxk_history_synchronizer CASCADE;
CREATE TABLE mxk_history_synchronizer (
    id varchar(45) NOT NULL,
    syncid varchar(45) NOT NULL,
    syncname varchar(45) DEFAULT NULL,
    objectid varchar(45) DEFAULT NULL,
    objectname varchar(45) DEFAULT NULL,
    objecttype varchar(45) DEFAULT NULL,
    synctime timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    result varchar(45) DEFAULT NULL,
    instid varchar(45) NOT NULL,
    PRIMARY KEY (id)
);
COMMENT ON TABLE mxk_history_synchronizer IS E'synchronizer logs';
COMMENT ON COLUMN mxk_history_synchronizer.id IS E'ID';
COMMENT ON COLUMN mxk_history_synchronizer.syncid IS E'SYNCID';
COMMENT ON COLUMN mxk_history_synchronizer.syncname IS E'SYNCNAME';
COMMENT ON COLUMN mxk_history_synchronizer.objectid IS E'OBJECTID';
COMMENT ON COLUMN mxk_history_synchronizer.objectname IS E'OBJECTNAME';
COMMENT ON COLUMN mxk_history_synchronizer.objecttype IS E'OBJECTTYPE';
COMMENT ON COLUMN mxk_history_synchronizer.synctime IS E'SYNCTIME';
DROP TABLE IF EXISTS mxk_history_system_logs CASCADE;
CREATE TABLE mxk_history_system_logs (
    id varchar(45) NOT NULL,
    topic varchar(100) DEFAULT NULL,
    message varchar(200) DEFAULT NULL,
    messageaction varchar(45) DEFAULT NULL,
    messageresult varchar(45) DEFAULT NULL,
    userid varchar(45) DEFAULT NULL,
    username varchar(45) DEFAULT NULL,
    displayname varchar(45) DEFAULT NULL,
    executetime timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    instid varchar(45) NOT NULL,
    PRIMARY KEY (id)
);
COMMENT ON TABLE mxk_history_system_logs IS E'USER OPERATE LOGS';
COMMENT ON COLUMN mxk_history_system_logs.id IS E'ID';
COMMENT ON COLUMN mxk_history_system_logs.topic IS E'SERVICENAME';
COMMENT ON COLUMN mxk_history_system_logs.message IS E'MESSAGE';
COMMENT ON COLUMN mxk_history_system_logs.messageaction IS E'OPERATETYPE';
COMMENT ON COLUMN mxk_history_system_logs.messageresult IS E'MESSAGETYPE';
COMMENT ON COLUMN mxk_history_system_logs.userid IS E'TID';
COMMENT ON COLUMN mxk_history_system_logs.username IS E'USERNAME';
COMMENT ON COLUMN mxk_history_system_logs.displayname IS E'CODE';
COMMENT ON COLUMN mxk_history_system_logs.executetime IS E'CREATEDDATE';
DROP TABLE IF EXISTS mxk_institutions CASCADE;
CREATE TABLE mxk_institutions (
    id varchar(45) NOT NULL,
    name varchar(200) NOT NULL,
    fullname varchar(100) DEFAULT NULL,
    division varchar(45) DEFAULT NULL,
    country varchar(45) DEFAULT NULL,
    region varchar(45) DEFAULT NULL,
    locality varchar(45) DEFAULT NULL,
    street varchar(45) DEFAULT NULL,
    contact varchar(45) DEFAULT NULL,
    address varchar(200) DEFAULT NULL,
    postalcode varchar(45) DEFAULT NULL,
    phone varchar(200) DEFAULT NULL,
    fax varchar(200) DEFAULT NULL,
    email varchar(45) DEFAULT NULL,
    sortindex integer DEFAULT '0',
    logo varchar(500) DEFAULT NULL,
    domain varchar(200) DEFAULT NULL,
    fronttitle varchar(200) DEFAULT NULL,
    consoledomain varchar(45) DEFAULT NULL,
    consoletitle varchar(200) DEFAULT NULL,
    captcha varchar(45) DEFAULT 'NONE,TEXT,ARITHMETIC',
    defaulturi varchar(200) DEFAULT NULL,
    status smallint DEFAULT NULL,
    description varchar(200) DEFAULT NULL,
    instid varchar(45) DEFAULT NULL,
    createdby varchar(45) DEFAULT NULL,
    createddate timestamp DEFAULT CURRENT_TIMESTAMP,
    modifiedby varchar(45) DEFAULT NULL,
    modifieddate timestamp DEFAULT NULL,
    PRIMARY KEY (id),
    CONSTRAINT domain_unique UNIQUE (domain)
);
COMMENT ON TABLE mxk_institutions IS E'institutions机构表，存放租户信息multi-tenancy';
DROP TABLE IF EXISTS mxk_localization CASCADE;
CREATE TABLE mxk_localization (
    id varchar(45) NOT NULL,
    property varchar(200) DEFAULT NULL,
    status integer DEFAULT NULL,
    description varchar(500) DEFAULT NULL,
    langzh varchar(500) DEFAULT NULL,
    langen varchar(500) DEFAULT NULL,
    instid varchar(45) DEFAULT NULL,
    PRIMARY KEY (id)
);
DROP TABLE IF EXISTS mxk_organizations CASCADE;
CREATE TABLE mxk_organizations (
    id varchar(45) NOT NULL,
    orgcode varchar(45) DEFAULT NULL,
    orgname varchar(200) NOT NULL,
    fullname varchar(100) DEFAULT NULL,
    type varchar(45) DEFAULT NULL,
    level integer DEFAULT NULL,
    parentid varchar(45) DEFAULT NULL,
    parentcode varchar(45) DEFAULT NULL,
    parentname varchar(45) DEFAULT NULL,
    codepath varchar(500) DEFAULT NULL,
    namepath varchar(400) DEFAULT NULL,
    description varchar(200) DEFAULT NULL,
    status smallint DEFAULT NULL,
    createdby varchar(45) DEFAULT NULL,
    createddate timestamp DEFAULT CURRENT_TIMESTAMP,
    modifiedby varchar(45) DEFAULT NULL,
    modifieddate timestamp DEFAULT NULL,
    address varchar(200) DEFAULT NULL,
    postalcode varchar(45) DEFAULT NULL,
    phone varchar(200) DEFAULT NULL,
    fax varchar(200) DEFAULT NULL,
    sortindex integer DEFAULT '0',
    division varchar(45) DEFAULT NULL,
    country varchar(45) DEFAULT NULL,
    region varchar(45) DEFAULT NULL,
    locality varchar(45) DEFAULT NULL,
    street varchar(45) DEFAULT NULL,
    haschild varchar(45) DEFAULT NULL,
    contact varchar(45) DEFAULT NULL,
    email varchar(45) DEFAULT NULL,
    ldapdn varchar(1000) DEFAULT NULL,
    instid varchar(45) NOT NULL,
    PRIMARY KEY (id)
);
DROP TABLE IF EXISTS mxk_organizations_cast CASCADE;
CREATE TABLE mxk_organizations_cast (
    id varchar(45) NOT NULL,
    code varchar(45) DEFAULT NULL,
    name varchar(200) NOT NULL,
    fullname varchar(100) DEFAULT NULL,
    parentid varchar(45) DEFAULT NULL,
    parentname varchar(45) DEFAULT NULL,
    codepath varchar(500) DEFAULT NULL,
    namepath varchar(400) DEFAULT NULL,
    sortindex integer DEFAULT NULL,
    status smallint DEFAULT NULL,
    provider varchar(45) DEFAULT NULL,
    orgid varchar(45) DEFAULT NULL,
    orgparentid varchar(45) DEFAULT NULL,
    instid varchar(45) NOT NULL,
    createdby varchar(45) DEFAULT NULL,
    createddate timestamp DEFAULT CURRENT_TIMESTAMP,
    modifiedby varchar(45) DEFAULT NULL,
    modifieddate timestamp DEFAULT NULL,
    PRIMARY KEY (id)
);
COMMENT ON TABLE mxk_organizations_cast IS E'机构映射表';
COMMENT ON COLUMN mxk_organizations_cast.id IS E'ID';
COMMENT ON COLUMN mxk_organizations_cast.code IS E'机构编码';
COMMENT ON COLUMN mxk_organizations_cast.name IS E'机构名称';
COMMENT ON COLUMN mxk_organizations_cast.parentid IS E'父级ID';
COMMENT ON COLUMN mxk_organizations_cast.parentname IS E'父级名称';
COMMENT ON COLUMN mxk_organizations_cast.codepath IS E'CODE路径';
COMMENT ON COLUMN mxk_organizations_cast.namepath IS E'名称路径';
COMMENT ON COLUMN mxk_organizations_cast.provider IS E'机构提供者';
COMMENT ON COLUMN mxk_organizations_cast.orgid IS E'MXK机构id';
COMMENT ON COLUMN mxk_organizations_cast.orgparentid IS E'MXK机构PARENTID';
COMMENT ON COLUMN mxk_organizations_cast.createdby IS E'CREATEDBY';
COMMENT ON COLUMN mxk_organizations_cast.createddate IS E'CREATEDDATE';
COMMENT ON COLUMN mxk_organizations_cast.modifiedby IS E'MODIFIEDBY';
COMMENT ON COLUMN mxk_organizations_cast.modifieddate IS E'MODIFIEDDATE';
DROP TABLE IF EXISTS mxk_passkey_challenges CASCADE;
CREATE TABLE mxk_passkey_challenges (
    id varchar(40) NOT NULL,
    user_id varchar(40) DEFAULT NULL,
    challenge text NOT NULL,
    challenge_type varchar(20) NOT NULL,
    created_date timestamp NOT NULL,
    expires_date timestamp NOT NULL,
    status integer DEFAULT '0',
    inst_id varchar(40) DEFAULT '1',
    PRIMARY KEY (id)
);
COMMENT ON TABLE mxk_passkey_challenges IS E'Passkey挑战表';
COMMENT ON COLUMN mxk_passkey_challenges.id IS E'挑战ID';
COMMENT ON COLUMN mxk_passkey_challenges.user_id IS E'用户ID（认证时可为空）';
COMMENT ON COLUMN mxk_passkey_challenges.challenge IS E'挑战数据（Base64编码）';
COMMENT ON COLUMN mxk_passkey_challenges.challenge_type IS E'挑战类型：REGISTRATION-注册，AUTHENTICATION-认证';
COMMENT ON COLUMN mxk_passkey_challenges.created_date IS E'创建时间';
COMMENT ON COLUMN mxk_passkey_challenges.expires_date IS E'过期时间';
COMMENT ON COLUMN mxk_passkey_challenges.status IS E'状态：0-未使用，1-已使用';
COMMENT ON COLUMN mxk_passkey_challenges.inst_id IS E'机构ID';
CREATE INDEX mxk_passkey_challenges_idx_user_id ON mxk_passkey_challenges (user_id);
CREATE INDEX mxk_passkey_challenges_idx_challenge_type ON mxk_passkey_challenges (challenge_type);
CREATE INDEX mxk_passkey_challenges_idx_expires_date ON mxk_passkey_challenges (expires_date);
CREATE INDEX mxk_passkey_challenges_idx_inst_id ON mxk_passkey_challenges (inst_id);
CREATE INDEX mxk_passkey_challenges_idx_status ON mxk_passkey_challenges (status);
CREATE INDEX mxk_passkey_challenges_idx_passkey_challenges_expires_status ON mxk_passkey_challenges (expires_date, status);
CREATE INDEX mxk_passkey_challenges_idx_passkey_challenges_user_type ON mxk_passkey_challenges (user_id, challenge_type);
DROP TABLE IF EXISTS mxk_permission CASCADE;
CREATE TABLE mxk_permission (
    id varchar(50) NOT NULL,
    appid varchar(50) DEFAULT NULL,
    groupid varchar(50) DEFAULT NULL,
    resourceid varchar(50) DEFAULT NULL,
    createdby varchar(45) DEFAULT NULL,
    createddate timestamp DEFAULT CURRENT_TIMESTAMP,
    status integer DEFAULT '1',
    instid varchar(45) DEFAULT NULL
);
DROP TABLE IF EXISTS mxk_permission_role CASCADE;
CREATE TABLE mxk_permission_role (
    id varchar(50) NOT NULL,
    appid varchar(50) DEFAULT NULL,
    roleid varchar(50) DEFAULT NULL,
    resourceid varchar(50) DEFAULT NULL,
    createdby varchar(45) DEFAULT NULL,
    createddate timestamp DEFAULT CURRENT_TIMESTAMP,
    status integer DEFAULT '1',
    instid varchar(45) DEFAULT NULL,
    PRIMARY KEY (id)
);
DROP TABLE IF EXISTS mxk_register CASCADE;
CREATE TABLE mxk_register (
    id varchar(50) NOT NULL,
    displayname varchar(200) DEFAULT NULL,
    workemail varchar(100) DEFAULT NULL,
    workphone varchar(50) DEFAULT NULL,
    employees integer DEFAULT NULL,
    instname varchar(200) DEFAULT NULL,
    status integer DEFAULT NULL,
    createdby varchar(50) DEFAULT NULL,
    createddate timestamp DEFAULT CURRENT_TIMESTAMP,
    modifiedby varchar(50) DEFAULT NULL,
    modifieddate timestamp DEFAULT NULL,
    PRIMARY KEY (id)
);
DROP TABLE IF EXISTS mxk_remember_me CASCADE;
CREATE TABLE mxk_remember_me (
    id varchar(45) NOT NULL,
    userid varchar(45) DEFAULT NULL,
    username varchar(45) DEFAULT NULL,
    lastlogintime varchar(45) DEFAULT NULL,
    expirationtime varchar(45) DEFAULT NULL,
    PRIMARY KEY (id)
);
DROP TABLE IF EXISTS mxk_resources CASCADE;
CREATE TABLE mxk_resources (
    id varchar(50) NOT NULL,
    resourcename varchar(200) DEFAULT NULL,
    resourcetype varchar(50) DEFAULT NULL,
    resourceurl varchar(500) DEFAULT NULL,
    permission varchar(500) DEFAULT NULL,
    status varchar(45) DEFAULT NULL,
    description varchar(500) DEFAULT NULL,
    createdby varchar(45) DEFAULT NULL,
    createddate timestamp DEFAULT CURRENT_TIMESTAMP,
    modifiedby varchar(45) DEFAULT NULL,
    modifieddate timestamp DEFAULT NULL,
    parentid varchar(50) DEFAULT NULL,
    parentname varchar(200) DEFAULT NULL,
    appid varchar(50) DEFAULT NULL,
    resourceaction varchar(200) DEFAULT NULL,
    resourceicon varchar(100) DEFAULT NULL,
    resourcestyle varchar(500) DEFAULT NULL,
    sortindex integer DEFAULT NULL,
    instid varchar(45) NOT NULL,
    PRIMARY KEY (id)
);
DROP TABLE IF EXISTS mxk_role_member CASCADE;
CREATE TABLE mxk_role_member (
    id varchar(100) NOT NULL DEFAULT '',
    roleid varchar(100) NOT NULL,
    memberid varchar(100) NOT NULL,
    type varchar(45) NOT NULL,
    createddate timestamp DEFAULT CURRENT_TIMESTAMP,
    instid varchar(45) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT roleid_memberid UNIQUE (roleid, memberid, type)
);
COMMENT ON TABLE mxk_role_member IS E'group member,USERS OR GROUPS';
COMMENT ON COLUMN mxk_role_member.id IS E'ID';
COMMENT ON COLUMN mxk_role_member.roleid IS E'GROUPID';
COMMENT ON COLUMN mxk_role_member.memberid IS E'MEMBERID USERID OR GROUP ID';
COMMENT ON COLUMN mxk_role_member.type IS E'TYPE  USER OR GROUP';
DROP TABLE IF EXISTS mxk_roles CASCADE;
CREATE TABLE mxk_roles (
    id varchar(45) NOT NULL,
    rolecode varchar(45) DEFAULT NULL,
    rolename varchar(100) DEFAULT NULL,
    category varchar(20) DEFAULT NULL,
    filters text,
    orgidslist text,
    resumetime varchar(45) DEFAULT NULL,
    suspendtime varchar(45) DEFAULT NULL,
    status smallint DEFAULT NULL,
    isdefault smallint DEFAULT NULL,
    createdby varchar(45) DEFAULT NULL,
    createddate timestamp DEFAULT CURRENT_TIMESTAMP,
    modifiedby varchar(45) DEFAULT NULL,
    modifieddate timestamp DEFAULT NULL,
    description varchar(500) DEFAULT NULL,
    instid varchar(45) NOT NULL,
    appid varchar(45) DEFAULT NULL,
    PRIMARY KEY (id)
);
COMMENT ON TABLE mxk_roles IS E'groups';
COMMENT ON COLUMN mxk_roles.id IS E'ID';
COMMENT ON COLUMN mxk_roles.rolename IS E'GROUP NAME';
COMMENT ON COLUMN mxk_roles.category IS E'动态用户组，dynamic动态组 static静态组app应用账号组';
COMMENT ON COLUMN mxk_roles.filters IS E'过滤条件SQL';
COMMENT ON COLUMN mxk_roles.orgidslist IS E'机构列表';
COMMENT ON COLUMN mxk_roles.resumetime IS E'RESUMETIME';
COMMENT ON COLUMN mxk_roles.suspendtime IS E'SUSPENDTIME';
COMMENT ON COLUMN mxk_roles.status IS E'STATUS';
COMMENT ON COLUMN mxk_roles.isdefault IS E'ISDEFAULT';
COMMENT ON COLUMN mxk_roles.createdby IS E'CREATEDBY';
COMMENT ON COLUMN mxk_roles.createddate IS E'CREATEDDATE';
COMMENT ON COLUMN mxk_roles.modifiedby IS E'MODIFIEDBY';
COMMENT ON COLUMN mxk_roles.modifieddate IS E'MODIFIEDDATE';
COMMENT ON COLUMN mxk_roles.description IS E'DESCRIPTION';
DROP TABLE IF EXISTS mxk_socials_associate CASCADE;
CREATE TABLE mxk_socials_associate (
    id varchar(45) NOT NULL,
    userid varchar(45) NOT NULL,
    username varchar(45) NOT NULL,
    provider varchar(45) NOT NULL,
    socialuserinfo text,
    socialuserid varchar(100) NOT NULL,
    exattribute text,
    accesstoken text,
    createddate timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updateddate timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    transmission varchar(45) DEFAULT 'automatic',
    instid varchar(45) NOT NULL,
    PRIMARY KEY (id)
);
COMMENT ON TABLE mxk_socials_associate IS E'socialsignon USER BIND';
COMMENT ON COLUMN mxk_socials_associate.userid IS E'USERID';
COMMENT ON COLUMN mxk_socials_associate.provider IS E'PROVIDER';
COMMENT ON COLUMN mxk_socials_associate.socialuserinfo IS E'SOCIALUSERINFO';
COMMENT ON COLUMN mxk_socials_associate.socialuserid IS E'SOCIALUSERID';
DROP TABLE IF EXISTS mxk_socials_provider CASCADE;
CREATE TABLE mxk_socials_provider (
    id varchar(45) NOT NULL,
    provider varchar(45) DEFAULT NULL,
    providername varchar(45) DEFAULT NULL,
    icon varchar(45) DEFAULT NULL,
    clientid varchar(100) DEFAULT NULL,
    clientsecret varchar(500) DEFAULT NULL,
    agentid varchar(45) DEFAULT NULL,
    display varchar(45) DEFAULT 'false',
    sortindex integer DEFAULT '1',
    scancode varchar(45) DEFAULT 'none',
    status integer DEFAULT '1',
    createdby varchar(45) DEFAULT NULL,
    createddate timestamp DEFAULT CURRENT_TIMESTAMP,
    modifiedby varchar(45) DEFAULT NULL,
    modifieddate timestamp DEFAULT NULL,
    instid varchar(45) NOT NULL,
    PRIMARY KEY (id)
);
DROP TABLE IF EXISTS mxk_synchro_association CASCADE;
CREATE TABLE mxk_synchro_association (
    id bigint GENERATED BY DEFAULT AS IDENTITY,
    syncid bigint NOT NULL DEFAULT '0',
    name varchar(64) DEFAULT '',
    objecttype varchar(10) DEFAULT '',
    targetfield varchar(64) DEFAULT '',
    targetfieldname varchar(64) DEFAULT '',
    sourcefield varchar(64) DEFAULT '',
    sourcefieldname varchar(64) DEFAULT '',
    description varchar(200) DEFAULT '',
    createuser bigint DEFAULT '0',
    createtime timestamp DEFAULT NULL,
    updateuser bigint DEFAULT '0',
    updatetime timestamp DEFAULT NULL,
    instid varchar(45) DEFAULT '1',
    PRIMARY KEY (id)
);
COMMENT ON TABLE mxk_synchro_association IS E'同步任务字段映射表';
COMMENT ON COLUMN mxk_synchro_association.id IS E'ID';
COMMENT ON COLUMN mxk_synchro_association.syncid IS E'同步任务ID';
COMMENT ON COLUMN mxk_synchro_association.name IS E'规则名';
COMMENT ON COLUMN mxk_synchro_association.objecttype IS E'类型';
COMMENT ON COLUMN mxk_synchro_association.targetfield IS E'目标字段';
COMMENT ON COLUMN mxk_synchro_association.targetfieldname IS E'目标字段描述';
COMMENT ON COLUMN mxk_synchro_association.sourcefield IS E'来源字段';
COMMENT ON COLUMN mxk_synchro_association.sourcefieldname IS E'来源字段描述';
COMMENT ON COLUMN mxk_synchro_association.description IS E'描述';
COMMENT ON COLUMN mxk_synchro_association.createuser IS E'创建人';
COMMENT ON COLUMN mxk_synchro_association.createtime IS E'创建时间';
COMMENT ON COLUMN mxk_synchro_association.updateuser IS E'修改人';
COMMENT ON COLUMN mxk_synchro_association.updatetime IS E'修改时间';
CREATE INDEX mxk_synchro_association_idx_job_id ON mxk_synchro_association (syncid);
DROP TABLE IF EXISTS mxk_synchro_related CASCADE;
CREATE TABLE mxk_synchro_related (
    id varchar(45) NOT NULL,
    objectid varchar(45) DEFAULT NULL,
    objectname varchar(200) DEFAULT NULL,
    objectdisplayname varchar(200) DEFAULT NULL,
    objecttype varchar(45) DEFAULT NULL,
    syncid varchar(100) DEFAULT NULL,
    syncname varchar(200) DEFAULT NULL,
    originid varchar(1000) DEFAULT NULL,
    originid2 varchar(200) DEFAULT NULL,
    originid3 varchar(200) DEFAULT NULL,
    instid varchar(45) DEFAULT NULL,
    synctime timestamp DEFAULT CURRENT_TIMESTAMP,
    originname varchar(500) DEFAULT NULL,
    PRIMARY KEY (id)
);
DROP TABLE IF EXISTS mxk_synchronizers CASCADE;
CREATE TABLE mxk_synchronizers (
    id varchar(50) NOT NULL,
    name varchar(200) DEFAULT NULL,
    service varchar(45) DEFAULT NULL,
    sourcetype varchar(45) DEFAULT NULL,
    scheduler varchar(45) DEFAULT NULL,
    providerurl varchar(400) DEFAULT NULL,
    driverclass varchar(400) DEFAULT NULL,
    principal varchar(200) DEFAULT NULL,
    credentials varchar(500) DEFAULT NULL,
    resumetime varchar(45) DEFAULT NULL,
    suspendtime varchar(45) DEFAULT NULL,
    userbasedn varchar(200) DEFAULT NULL,
    userfilters varchar(4000) DEFAULT NULL,
    orgbasedn varchar(200) DEFAULT NULL,
    orgfilters varchar(4000) DEFAULT NULL,
    msaddomain varchar(45) DEFAULT NULL,
    sslswitch varchar(45) DEFAULT NULL,
    truststore varchar(45) DEFAULT NULL,
    truststorepassword varchar(45) DEFAULT NULL,
    syncstarttime integer DEFAULT '0',
    status varchar(45) DEFAULT NULL,
    createdby varchar(45) DEFAULT NULL,
    createddate timestamp DEFAULT CURRENT_TIMESTAMP,
    modifiedby varchar(45) DEFAULT NULL,
    modifieddate timestamp DEFAULT NULL,
    description varchar(45) DEFAULT NULL,
    instid varchar(45) NOT NULL,
    appid varchar(45) DEFAULT NULL,
    appname varchar(45) DEFAULT NULL,
    PRIMARY KEY (id)
);
COMMENT ON TABLE mxk_synchronizers IS E'同步器';
COMMENT ON COLUMN mxk_synchronizers.syncstarttime IS E'同步时间范围（单位天）';
DROP TABLE IF EXISTS mxk_user_passkeys CASCADE;
CREATE TABLE mxk_user_passkeys (
    id varchar(40) NOT NULL,
    user_id varchar(40) NOT NULL,
    credential_id varchar(500) NOT NULL,
    public_key text NOT NULL,
    display_name varchar(100) DEFAULT NULL,
    device_type varchar(50) DEFAULT 'unknown',
    signature_count bigint DEFAULT '0',
    created_date timestamp NOT NULL,
    last_used_date timestamp DEFAULT NULL,
    aaguid varchar(100) DEFAULT NULL,
    inst_id varchar(40) DEFAULT '1',
    status integer DEFAULT '1',
    PRIMARY KEY (id),
    CONSTRAINT uk_credential_id UNIQUE (credential_id)
);
COMMENT ON TABLE mxk_user_passkeys IS E'用户Passkey凭据表';
COMMENT ON COLUMN mxk_user_passkeys.id IS E'主键ID';
COMMENT ON COLUMN mxk_user_passkeys.user_id IS E'用户ID';
COMMENT ON COLUMN mxk_user_passkeys.credential_id IS E'凭据ID（Base64编码）';
COMMENT ON COLUMN mxk_user_passkeys.public_key IS E'公钥数据（Base64编码）';
COMMENT ON COLUMN mxk_user_passkeys.display_name IS E'显示名称';
COMMENT ON COLUMN mxk_user_passkeys.device_type IS E'设备类型';
COMMENT ON COLUMN mxk_user_passkeys.signature_count IS E'签名计数器';
COMMENT ON COLUMN mxk_user_passkeys.created_date IS E'创建时间';
COMMENT ON COLUMN mxk_user_passkeys.last_used_date IS E'最后使用时间';
COMMENT ON COLUMN mxk_user_passkeys.aaguid IS E'AAGUID';
COMMENT ON COLUMN mxk_user_passkeys.inst_id IS E'机构ID';
COMMENT ON COLUMN mxk_user_passkeys.status IS E'状态：1-正常，0-禁用';
CREATE INDEX mxk_user_passkeys_idx_user_id ON mxk_user_passkeys (user_id);
CREATE INDEX mxk_user_passkeys_idx_inst_id ON mxk_user_passkeys (inst_id);
CREATE INDEX mxk_user_passkeys_idx_created_date ON mxk_user_passkeys (created_date);
CREATE INDEX mxk_user_passkeys_idx_user_passkeys_user_status ON mxk_user_passkeys (user_id, status);
DROP TABLE IF EXISTS mxk_userinfo CASCADE;
CREATE TABLE mxk_userinfo (
    id varchar(45) NOT NULL,
    username varchar(100) NOT NULL,
    password varchar(500) NOT NULL,
    decipherable varchar(500) NOT NULL,
    authntype smallint DEFAULT '1',
    mobile varchar(45) DEFAULT NULL,
    mobileverified varchar(45) DEFAULT NULL,
    email varchar(45) DEFAULT NULL,
    emailverified smallint DEFAULT NULL,
    displayname varchar(45) DEFAULT NULL,
    nickname varchar(45) DEFAULT NULL,
    picture bytea,
    timezone varchar(45) DEFAULT 'Asia/Shanghai',
    locale varchar(45) DEFAULT 'zh_CN',
    preferredlanguage varchar(45) DEFAULT 'zh_CN',
    passwordquestion varchar(45) DEFAULT NULL,
    passwordanswer varchar(45) DEFAULT NULL,
    apploginauthntype smallint DEFAULT '0',
    apploginpassword varchar(45) DEFAULT NULL,
    protectedapps varchar(450) DEFAULT NULL,
    theme varchar(45) DEFAULT 'default',
    gridlist smallint DEFAULT '0',
    logincount integer DEFAULT '0',
    "online" smallint DEFAULT '0',
    status smallint DEFAULT '1',
    islocked smallint DEFAULT '1',
    unlocktime timestamp DEFAULT '2020-01-01 01:01:01',
    lastloginip varchar(300) DEFAULT NULL,
    lastlogintime timestamp DEFAULT '2020-01-01 01:01:01',
    lastlogofftime timestamp DEFAULT '2020-01-01 01:01:01',
    badpasswordtime timestamp DEFAULT '2020-01-01 01:01:01',
    badpasswordcount smallint DEFAULT NULL,
    passwordlastsettime timestamp DEFAULT '2020-01-01 01:01:01',
    passwordsettype smallint DEFAULT '0',
    sharedsecret varchar(500) DEFAULT NULL,
    sharedcounter varchar(45) DEFAULT '0',
    usertype varchar(45) DEFAULT 'Customer',
    userstate varchar(45) DEFAULT 'RESIDENT',
    employeenumber varchar(45) DEFAULT NULL,
    windowsaccount varchar(45) DEFAULT NULL,
    division varchar(45) DEFAULT NULL,
    costcenter varchar(45) DEFAULT NULL,
    organization varchar(45) DEFAULT NULL,
    departmentid varchar(45) DEFAULT NULL,
    department varchar(45) DEFAULT NULL,
    jobtitle varchar(45) DEFAULT NULL,
    joblevel varchar(45) DEFAULT NULL,
    managerid varchar(45) DEFAULT NULL,
    manager varchar(45) DEFAULT NULL,
    assistantid varchar(45) DEFAULT NULL,
    assistant varchar(45) DEFAULT NULL,
    entrydate varchar(45) DEFAULT NULL,
    startworkdate varchar(45) DEFAULT NULL,
    quitdate varchar(45) DEFAULT NULL,
    sortindex smallint DEFAULT '1',
    workemail varchar(45) DEFAULT NULL,
    workphonenumber varchar(45) DEFAULT NULL,
    workcountry varchar(45) DEFAULT 'CHN',
    workregion varchar(45) DEFAULT NULL,
    worklocality varchar(45) DEFAULT NULL,
    workstreetaddress varchar(45) DEFAULT NULL,
    workaddressformatted varchar(45) DEFAULT NULL,
    workpostalcode varchar(45) DEFAULT NULL,
    workfax varchar(45) DEFAULT NULL,
    workofficename varchar(500) DEFAULT NULL,
    givenname varchar(45) DEFAULT NULL,
    middlename varchar(45) DEFAULT NULL,
    familyname varchar(45) DEFAULT NULL,
    honorificprefix varchar(45) DEFAULT NULL,
    honorificsuffix varchar(45) DEFAULT NULL,
    formattedname varchar(400) DEFAULT NULL,
    idtype smallint DEFAULT '0',
    idcardno varchar(45) DEFAULT NULL,
    education varchar(200) DEFAULT NULL,
    graduatefrom varchar(500) DEFAULT NULL,
    graduatedate varchar(45) DEFAULT NULL,
    married smallint DEFAULT '0',
    birthdate varchar(45) DEFAULT NULL,
    namezhspell varchar(100) DEFAULT NULL,
    namezhshortspell varchar(45) DEFAULT NULL,
    gender smallint DEFAULT NULL,
    website varchar(50) DEFAULT NULL,
    weixinfollow smallint DEFAULT NULL,
    defineim varchar(45) DEFAULT NULL,
    homeemail varchar(45) DEFAULT NULL,
    homephonenumber varchar(45) DEFAULT NULL,
    homecountry varchar(45) DEFAULT 'CHN',
    homeregion varchar(45) DEFAULT NULL,
    homelocality varchar(45) DEFAULT NULL,
    homestreetaddress varchar(45) DEFAULT NULL,
    homeaddressformatted varchar(45) DEFAULT NULL,
    homepostalcode varchar(45) DEFAULT NULL,
    homefax varchar(45) DEFAULT NULL,
    extraattribute varchar(4000) DEFAULT NULL,
    createdby varchar(45) DEFAULT NULL,
    createddate timestamp DEFAULT CURRENT_TIMESTAMP,
    modifiedby varchar(45) DEFAULT NULL,
    modifieddate timestamp DEFAULT NULL,
    description varchar(400) DEFAULT NULL,
    ldapdn varchar(1000) DEFAULT NULL,
    instid varchar(45) NOT NULL,
    regionhistory text,
    passwordhistory text,
    PRIMARY KEY (id),
    CONSTRAINT username_unique UNIQUE (username)
);
COMMENT ON TABLE mxk_userinfo IS E'USER INFO DEFINE';
COMMENT ON COLUMN mxk_userinfo.id IS E'编号';
COMMENT ON COLUMN mxk_userinfo.username IS E'登录名';
COMMENT ON COLUMN mxk_userinfo.password IS E'密码';
COMMENT ON COLUMN mxk_userinfo.decipherable IS E'DE密码';
COMMENT ON COLUMN mxk_userinfo.authntype IS E'认证类型';
COMMENT ON COLUMN mxk_userinfo.mobile IS E'手机号码';
COMMENT ON COLUMN mxk_userinfo.mobileverified IS E'手机号验证';
COMMENT ON COLUMN mxk_userinfo.email IS E'邮箱';
COMMENT ON COLUMN mxk_userinfo.emailverified IS E'邮箱验证';
COMMENT ON COLUMN mxk_userinfo.displayname IS E'显示名称';
COMMENT ON COLUMN mxk_userinfo.nickname IS E'昵称';
COMMENT ON COLUMN mxk_userinfo.picture IS E'头像';
COMMENT ON COLUMN mxk_userinfo.timezone IS E'时区';
COMMENT ON COLUMN mxk_userinfo.locale IS E'地址';
COMMENT ON COLUMN mxk_userinfo.preferredlanguage IS E'语言偏好';
COMMENT ON COLUMN mxk_userinfo.passwordquestion IS E'密码问题';
COMMENT ON COLUMN mxk_userinfo.passwordanswer IS E'密码答案';
COMMENT ON COLUMN mxk_userinfo.apploginauthntype IS E'应用登录认证类型';
COMMENT ON COLUMN mxk_userinfo.apploginpassword IS E'应用登录密码';
COMMENT ON COLUMN mxk_userinfo.protectedapps IS E'应用登录密码保护应用';
COMMENT ON COLUMN mxk_userinfo.theme IS E'主题';
COMMENT ON COLUMN mxk_userinfo.gridlist IS E'应用列表类型';
COMMENT ON COLUMN mxk_userinfo.logincount IS E'登录次数统计';
COMMENT ON COLUMN mxk_userinfo."online" IS E'在线状态';
COMMENT ON COLUMN mxk_userinfo.status IS E'用户状态';
COMMENT ON COLUMN mxk_userinfo.islocked IS E'锁定状态';
COMMENT ON COLUMN mxk_userinfo.unlocktime IS E'解锁时间';
COMMENT ON COLUMN mxk_userinfo.lastloginip IS E'最近登录IP地址';
COMMENT ON COLUMN mxk_userinfo.lastlogintime IS E'最近登录时间';
COMMENT ON COLUMN mxk_userinfo.lastlogofftime IS E'最近注销时间';
COMMENT ON COLUMN mxk_userinfo.badpasswordtime IS E'最近密码错误时间';
COMMENT ON COLUMN mxk_userinfo.badpasswordcount IS E'密码错误次数';
COMMENT ON COLUMN mxk_userinfo.passwordlastsettime IS E'最近密码修改时间';
COMMENT ON COLUMN mxk_userinfo.passwordsettype IS E'密码重置类型';
COMMENT ON COLUMN mxk_userinfo.sharedsecret IS E'TIME-OPT密钥';
COMMENT ON COLUMN mxk_userinfo.sharedcounter IS E'COUNTER-OPT密钥';
COMMENT ON COLUMN mxk_userinfo.usertype IS E'用户类型';
COMMENT ON COLUMN mxk_userinfo.employeenumber IS E'工号';
COMMENT ON COLUMN mxk_userinfo.windowsaccount IS E'AD域账号';
COMMENT ON COLUMN mxk_userinfo.division IS E'分支';
COMMENT ON COLUMN mxk_userinfo.costcenter IS E'成本中心';
COMMENT ON COLUMN mxk_userinfo.organization IS E'机构';
COMMENT ON COLUMN mxk_userinfo.departmentid IS E'部门编号';
COMMENT ON COLUMN mxk_userinfo.department IS E'部门';
COMMENT ON COLUMN mxk_userinfo.jobtitle IS E'职务';
COMMENT ON COLUMN mxk_userinfo.joblevel IS E'工作职级';
COMMENT ON COLUMN mxk_userinfo.managerid IS E'经理编号';
COMMENT ON COLUMN mxk_userinfo.manager IS E'经理名字';
COMMENT ON COLUMN mxk_userinfo.assistantid IS E'助理编号';
COMMENT ON COLUMN mxk_userinfo.assistant IS E'助理名字';
COMMENT ON COLUMN mxk_userinfo.entrydate IS E'入司时间';
COMMENT ON COLUMN mxk_userinfo.startworkdate IS E'开始工作时间';
COMMENT ON COLUMN mxk_userinfo.quitdate IS E'离职日期';
COMMENT ON COLUMN mxk_userinfo.sortindex IS E'部门内排序';
COMMENT ON COLUMN mxk_userinfo.workemail IS E'工作-邮件';
COMMENT ON COLUMN mxk_userinfo.workphonenumber IS E'工作-电话';
COMMENT ON COLUMN mxk_userinfo.workcountry IS E'工作-国家';
COMMENT ON COLUMN mxk_userinfo.workregion IS E'工作-省/市';
COMMENT ON COLUMN mxk_userinfo.worklocality IS E'工作-城市';
COMMENT ON COLUMN mxk_userinfo.workstreetaddress IS E'工作-街道';
COMMENT ON COLUMN mxk_userinfo.workaddressformatted IS E'工作-地址全称';
COMMENT ON COLUMN mxk_userinfo.workpostalcode IS E'工作-邮编';
COMMENT ON COLUMN mxk_userinfo.workfax IS E'工作-传真';
COMMENT ON COLUMN mxk_userinfo.givenname IS E'名';
COMMENT ON COLUMN mxk_userinfo.middlename IS E'中间名';
COMMENT ON COLUMN mxk_userinfo.familyname IS E'姓';
COMMENT ON COLUMN mxk_userinfo.honorificprefix IS E'前缀';
COMMENT ON COLUMN mxk_userinfo.honorificsuffix IS E'后缀';
COMMENT ON COLUMN mxk_userinfo.formattedname IS E'用户全名';
COMMENT ON COLUMN mxk_userinfo.idtype IS E'证件类型';
COMMENT ON COLUMN mxk_userinfo.idcardno IS E'证件号码';
COMMENT ON COLUMN mxk_userinfo.education IS E'学历';
COMMENT ON COLUMN mxk_userinfo.graduatefrom IS E'毕业院校';
COMMENT ON COLUMN mxk_userinfo.graduatedate IS E'毕业日期';
COMMENT ON COLUMN mxk_userinfo.married IS E'婚姻状态';
COMMENT ON COLUMN mxk_userinfo.birthdate IS E'生日';
COMMENT ON COLUMN mxk_userinfo.namezhspell IS E'名字中文拼音';
COMMENT ON COLUMN mxk_userinfo.namezhshortspell IS E'名字中文拼音简称';
COMMENT ON COLUMN mxk_userinfo.gender IS E'性别';
COMMENT ON COLUMN mxk_userinfo.website IS E'个人主页';
COMMENT ON COLUMN mxk_userinfo.weixinfollow IS E'微信关注';
COMMENT ON COLUMN mxk_userinfo.defineim IS E'IM账号';
COMMENT ON COLUMN mxk_userinfo.homeemail IS E'家庭-邮件';
COMMENT ON COLUMN mxk_userinfo.homephonenumber IS E'家庭-电话';
COMMENT ON COLUMN mxk_userinfo.homecountry IS E'家庭-省/市';
COMMENT ON COLUMN mxk_userinfo.homeregion IS E'家庭-市';
COMMENT ON COLUMN mxk_userinfo.homelocality IS E'家庭-区';
COMMENT ON COLUMN mxk_userinfo.homestreetaddress IS E'家庭-街道';
COMMENT ON COLUMN mxk_userinfo.homeaddressformatted IS E'家庭-地址全称';
COMMENT ON COLUMN mxk_userinfo.homepostalcode IS E'家庭-邮编';
COMMENT ON COLUMN mxk_userinfo.homefax IS E'家庭-传真';
COMMENT ON COLUMN mxk_userinfo.extraattribute IS E'用户扩展属性';
COMMENT ON COLUMN mxk_userinfo.createdby IS E'创建人';
COMMENT ON COLUMN mxk_userinfo.createddate IS E'创建时间';
COMMENT ON COLUMN mxk_userinfo.modifiedby IS E'修改人';
COMMENT ON COLUMN mxk_userinfo.modifieddate IS E'修改时间';
COMMENT ON COLUMN mxk_userinfo.description IS E'描述';
CREATE INDEX mxk_userinfo_employeenumber_unique ON mxk_userinfo (employeenumber);
INSERT INTO mxk_access (id, groupid, appid, createddate, instid) VALUES (E'1012788834292727808', E'ROLE_ALL_USER', E'622227747938373638', E'2024-07-22 15:42:20', E'1');
INSERT INTO mxk_access (id, groupid, appid, createddate, instid) VALUES (E'1012788853112569856', E'ROLE_ALL_USER', E'808307337319153664', E'2024-07-22 15:42:24', E'1');
INSERT INTO mxk_access (id, groupid, appid, createddate, instid) VALUES (E'1012788886906077184', E'ROLE_ALL_USER', E'820824743803355136', E'2024-07-22 15:42:32', E'1');
INSERT INTO mxk_access (id, groupid, appid, createddate, instid) VALUES (E'1012788887010934784', E'ROLE_ALL_USER', E'820990393884606464', E'2024-07-22 15:42:33', E'1');
INSERT INTO mxk_access (id, groupid, appid, createddate, instid) VALUES (E'1012788887078043648', E'ROLE_ALL_USER', E'820993743166373888', E'2024-07-22 15:42:33', E'1');
INSERT INTO mxk_access (id, groupid, appid, createddate, instid) VALUES (E'1012788887149346816', E'ROLE_ALL_USER', E'822177968448077824', E'2024-07-22 15:42:33', E'1');
INSERT INTO mxk_access (id, groupid, appid, createddate, instid) VALUES (E'1012789097627910144', E'ROLE_ADMINISTRATORS', E'807671808701497344', E'2024-07-22 15:43:23', E'1');
INSERT INTO mxk_access (id, groupid, appid, createddate, instid) VALUES (E'1012789097707601920', E'ROLE_ADMINISTRATORS', E'808307337319153664', E'2024-07-22 15:43:23', E'1');
INSERT INTO mxk_access (id, groupid, appid, createddate, instid) VALUES (E'1012789129005498368', E'ROLE_ADMINISTRATORS', E'820821184445677568', E'2024-07-22 15:43:30', E'1');
INSERT INTO mxk_access (id, groupid, appid, createddate, instid) VALUES (E'1012789129072607232', E'ROLE_ADMINISTRATORS', E'820822501587156992', E'2024-07-22 15:43:30', E'1');
INSERT INTO mxk_access (id, groupid, appid, createddate, instid) VALUES (E'1012789148022472704', E'ROLE_ADMINISTRATORS', E'820993743166373888', E'2024-07-22 15:43:35', E'1');
INSERT INTO mxk_access (id, groupid, appid, createddate, instid) VALUES (E'1012789161045786624', E'ROLE_ADMINISTRATORS', E'822177968448077824', E'2024-07-22 15:43:38', E'1');
INSERT INTO mxk_access (id, groupid, appid, createddate, instid) VALUES (E'1012789184466780160', E'ROLE_ADMINISTRATORS', E'824007723908595712', E'2024-07-22 15:43:43', E'1');
INSERT INTO mxk_access (id, groupid, appid, createddate, instid) VALUES (E'1012789194692493312', E'ROLE_ADMINISTRATORS', E'824009331925057536', E'2024-07-22 15:43:46', E'1');
INSERT INTO mxk_access (id, groupid, appid, createddate, instid) VALUES (E'1012789244566962176', E'ROLE_ADMINISTRATORS', E'837136275440926720', E'2024-07-22 15:43:58', E'1');
INSERT INTO mxk_access (id, groupid, appid, createddate, instid) VALUES (E'1037487192630362112', E'ROLE_ADMINISTRATORS', E'816077428370702336', E'2024-09-28 19:24:47', E'1');
INSERT INTO mxk_access (id, groupid, appid, createddate, instid) VALUES (E'1037500516352917504', E'ROLE_ADMINISTRATORS', E'622076759805923328', E'2024-09-28 20:17:44', E'1');
INSERT INTO mxk_access (id, groupid, appid, createddate, instid) VALUES (E'622237756604547072', E'ROLE_ADMINISTRATORS', E'622227747938373638', E'2021-08-09 22:31:47', E'1');
INSERT INTO mxk_access (id, groupid, appid, createddate, instid) VALUES (E'632391438314766336', E'ROLE_ADMINISTRATORS', E'632389704376909824', E'2021-09-06 22:58:53', E'1');
INSERT INTO mxk_access (id, groupid, appid, createddate, instid) VALUES (E'632584912179822592', E'ROLE_ADMINISTRATORS', E'632279563832918016', E'2021-09-07 11:47:42', E'1');
INSERT INTO mxk_access (id, groupid, appid, createddate, instid) VALUES (E'689200701791797248', E'ROLE_ADMINISTRATORS', E'689200399827075072', E'2022-02-10 17:18:37', E'1');
INSERT INTO mxk_access (id, groupid, appid, createddate, instid) VALUES (E'709137430816489472', E'622179035744567296', E'707902011902787584', E'2022-04-06 17:40:04', E'1');
INSERT INTO mxk_access (id, groupid, appid, createddate, instid) VALUES (E'837333028614176768', E'837332844740083712', E'837136275440926720', E'2023-03-26 11:43:36', E'1');
INSERT INTO mxk_access (id, groupid, appid, createddate, instid) VALUES (E'876893019578564608', E'ROLE_ADMINISTRATORS', E'876892492581044224', E'2023-07-13 15:40:53', E'1');
INSERT INTO mxk_apps (id, appname, loginurl, category, secret, protocol, icon, status, createdby, createddate, modifiedby, modifieddate, description, vendor, vendorurl, credential, sharedusername, sharedpassword, systemuserattr, isextendattr, extendattr, sortindex, issignature, visible, isadapter, adapterid, adaptername, adapter, principal, credentials, userpropertys, inducer, logouturl, logouttype, instid, frequently, resourcemgt, openapiright) VALUES (E'622076759805923328', E'MaxKey管理系统', E'http://mgt.maxkey.top/maxkey-mgt', E'none', E'$2a$10$NxCPqq1lYxvQ/ltrOeNmWO812ff6ed00de587a3850b541ac2ab23b0ceff2eb105486bf1f5ca181f3a6a1f557fdd6f9c5a3233381cb5cee9c2f0944c388b06de7cfd529', E'CAS', NULL, 1, NULL, E'2022-02-12 05:22:39', E'1', E'2026-07-20 19:54:45', E'', E'', E'', E'none', NULL, NULL, NULL, E'0', NULL, 8, 0, 0, 1, E'622227747946762290', E'CAS默认适配器', E'org.dromara.maxkey.authz.cas.adapter.CasDefaultAdapter', NULL, NULL, E'username', E'IDP', E'', 0, E'1', E'no', E'y', E'read');
INSERT INTO mxk_apps (id, appname, loginurl, category, secret, protocol, icon, status, createdby, createddate, modifiedby, modifieddate, description, vendor, vendorurl, credential, sharedusername, sharedpassword, systemuserattr, isextendattr, extendattr, sortindex, issignature, visible, isadapter, adapterid, adaptername, adapter, principal, credentials, userpropertys, inducer, logouturl, logouttype, instid, frequently, resourcemgt, openapiright) VALUES (E'622227747938373638', E'人力资源管理系统', E'http://hr.maxkey.top', E'1011', E'$2a$10$VbIYvyXge9BP5hiiAlXu5uad001aeca894bb54cfa8f1668b199423fde88499906416cf3211440bab39f3d7a47ff69c0f2add24887a44f9b914a0df722b9472747bef59', E'CAS', NULL, 1, NULL, NULL, E'1', E'2026-07-20 19:54:04', E'', E'MAXKEY', E'', E'none', NULL, NULL, NULL, E'0', NULL, 1, 0, 1, 1, NULL, E'CAS默认适配器', E'org.dromara.maxkey.authz.cas.adapter.CasDefaultAdapter', NULL, NULL, NULL, E'IDP', E'', 0, E'1', E'no', E'y', E'read');
INSERT INTO mxk_apps (id, appname, loginurl, category, secret, protocol, icon, status, createdby, createddate, modifiedby, modifieddate, description, vendor, vendorurl, credential, sharedusername, sharedpassword, systemuserattr, isextendattr, extendattr, sortindex, issignature, visible, isadapter, adapterid, adaptername, adapter, principal, credentials, userpropertys, inducer, logouturl, logouttype, instid, frequently, resourcemgt, openapiright) VALUES (E'632279563832918016', E'Jira', E'http://jira.maxkey.top:8080/plugins/servlet/easysso/saml', E'1111', E'$2a$10$nSYezVTzfwwVnNLdjz16pu4c55d5e5667c502f43b7b688033855fc44208b5b3c9fd04de535f5e9222eb6cdc53ac8305f5fad181bd55ebfd883213dc0005009967ce36b', E'SAML_v2.0', NULL, 1, NULL, NULL, NULL, NULL, E',', E'', E'', E'none', NULL, NULL, NULL, E'0', NULL, 1, 0, 1, 0, E'', E'', E'', NULL, NULL, NULL, E'IDP', E'', 0, E'1', E'no', E'n', E'read');
INSERT INTO mxk_apps (id, appname, loginurl, category, secret, protocol, icon, status, createdby, createddate, modifiedby, modifieddate, description, vendor, vendorurl, credential, sharedusername, sharedpassword, systemuserattr, isextendattr, extendattr, sortindex, issignature, visible, isadapter, adapterid, adaptername, adapter, principal, credentials, userpropertys, inducer, logouturl, logouttype, instid, frequently, resourcemgt, openapiright) VALUES (E'807666906197655552', E'Basic_Demo', E'http://www.baidu.com', E'none', E'$2a$10$/uDIebmv3PG42HOZi4EdUOd64d933608d48546a75d3e06fbdc78488b586f7981ae095ff6588785a26304056503e6dde21140b6a6593e63fd766d9aa0eaffe0f53a6d2e', E'Basic', NULL, 1, E'admin', E'2013-07-18 15:51:46', E'1', E'2026-07-20 19:06:03', E'Test', E'baidu', E'http://www.baidu.com', E'none', NULL, NULL, NULL, E'0', NULL, 16, 0, 1, 0, E'1020101', E'CAS默认适配器', E'org.dromara.maxkey.authz.cas.adapter.CasDefaultAdapter', NULL, NULL, NULL, E'IDP', E'', 0, E'1', E'no', E'n', E'read');
INSERT INTO mxk_apps (id, appname, loginurl, category, secret, protocol, icon, status, createdby, createddate, modifiedby, modifieddate, description, vendor, vendorurl, credential, sharedusername, sharedpassword, systemuserattr, isextendattr, extendattr, sortindex, issignature, visible, isadapter, adapterid, adaptername, adapter, principal, credentials, userpropertys, inducer, logouturl, logouttype, instid, frequently, resourcemgt, openapiright) VALUES (E'807667697885118464', E'JumpServer 堡垒机', E'http://jump.maxkey.top/core/auth/login/', E'1112', E'$2a$10$spT3d3g74ynjVBBjLKKelO612d5ce4a691917278906ce1976a1312860bfcbb43f26a204721766bd5721f17', E'CAS', NULL, 1, NULL, NULL, NULL, NULL, E'', E'杭州飞致云信息科技有限公司', E'https://www.jumpserver.org/', E'none', NULL, NULL, NULL, E'0', NULL, 6, 0, 1, 0, NULL, E'CAS默认适配器', E'org.dromara.maxkey.authz.cas.adapter.CasDefaultAdapter', NULL, NULL, NULL, E'IDP', NULL, 0, E'1', E'no', E'n', E'read');
INSERT INTO mxk_apps (id, appname, loginurl, category, secret, protocol, icon, status, createdby, createddate, modifiedby, modifieddate, description, vendor, vendorurl, credential, sharedusername, sharedpassword, systemuserattr, isextendattr, extendattr, sortindex, issignature, visible, isadapter, adapterid, adaptername, adapter, principal, credentials, userpropertys, inducer, logouturl, logouttype, instid, frequently, resourcemgt, openapiright) VALUES (E'807671808701497344', E'Jenkins', E'http://jenkins.maxkey.top:9523/jenkins', E'none', E'$2a$10$ApgEhgmFIukMKKu8BitjvOa21c1f20f7ea3c2712be891aebb7221118bdadae9de2f1fe4b5f712aae45a3bc', E'CAS', NULL, 1, NULL, NULL, NULL, NULL, E'项目管理', E'Jenkins', E'https://www.jenkins.io/', E'none', NULL, NULL, NULL, E'0', NULL, 4, 0, 1, 1, NULL, E'CAS默认适配器', E'org.dromara.maxkey.authz.cas.adapter.CasDefaultAdapter', NULL, NULL, NULL, E'IDP', E'http://localhost:8080/jenkins/securityRealm/finishLogin', 1, E'1', E'no', E'n', E'read');
INSERT INTO mxk_apps (id, appname, loginurl, category, secret, protocol, icon, status, createdby, createddate, modifiedby, modifieddate, description, vendor, vendorurl, credential, sharedusername, sharedpassword, systemuserattr, isextendattr, extendattr, sortindex, issignature, visible, isadapter, adapterid, adaptername, adapter, principal, credentials, userpropertys, inducer, logouturl, logouttype, instid, frequently, resourcemgt, openapiright) VALUES (E'808307337319153664', E'泛微OA', E'http://weaver.demo.maxkey.top:8080/weaver/OALogin.jsp', E'1013', E'$2a$10$kzMXtl0Vf9/emLBZby/56u3c9a978f841b8d2cd142ea16ac34285920d3e09d52563dc81acda96c1d83f403', E'CAS', NULL, 1, NULL, E'2020-07-03 15:00:18', NULL, NULL, E'', E'泛微', E'https://www.weaver.com.cn/', E'none', NULL, NULL, NULL, E'0', NULL, 8, 0, 1, 1, NULL, E'CAS默认适配器', E'org.dromara.maxkey.authz.cas.adapter.CasDefaultAdapter', NULL, NULL, NULL, E'IDP', NULL, 0, E'1', E'no', E'n', E'read');
INSERT INTO mxk_apps (id, appname, loginurl, category, secret, protocol, icon, status, createdby, createddate, modifiedby, modifieddate, description, vendor, vendorurl, credential, sharedusername, sharedpassword, systemuserattr, isextendattr, extendattr, sortindex, issignature, visible, isadapter, adapterid, adaptername, adapter, principal, credentials, userpropertys, inducer, logouturl, logouttype, instid, frequently, resourcemgt, openapiright) VALUES (E'808321992456404992', E'pac4j demo', E'http://app1.cas.com:8081/callback?client_name=pac4jclient1', E'none', E'$2a$10$uVcpOsNJo8FfSlyBmCg4k.218327db074cccd9128bbacda3aa47d9df977b901f36e99b9020a1546564c239', E'CAS', NULL, 1, NULL, NULL, NULL, NULL, E'pac4j ', E'pac4j ', E'pac4j ', E'none', NULL, NULL, NULL, E'0', NULL, 310, 0, 1, 1, NULL, E'CAS默认适配器', E'org.dromara.maxkey.authz.cas.adapter.CasDefaultAdapter', NULL, NULL, NULL, E'IDP', NULL, 0, E'1', E'no', E'n', E'read');
INSERT INTO mxk_apps (id, appname, loginurl, category, secret, protocol, icon, status, createdby, createddate, modifiedby, modifieddate, description, vendor, vendorurl, credential, sharedusername, sharedpassword, systemuserattr, isextendattr, extendattr, sortindex, issignature, visible, isadapter, adapterid, adaptername, adapter, principal, credentials, userpropertys, inducer, logouturl, logouttype, instid, frequently, resourcemgt, openapiright) VALUES (E'816077086090330112', E'CAS BackEnd Demo', E'http://cas-backend.demo.maxkey.top:9521/demo-cas-backend/', E'none', E'$2a$10$i3OJE/ctNzJUQscrQStzpe349f43852c44db540f34fa05dc276d496d8a8fabf9f25a9ba789035015f1dcb5', E'CAS', NULL, 1, NULL, NULL, NULL, NULL, E'', E'MaxKey', E'https://github.com/shimingxy/MaxKey', E'none', NULL, NULL, NULL, E'0', NULL, 303, 0, 1, 1, NULL, E'CAS默认适配器', E'org.dromara.maxkey.authz.cas.adapter.CasDefaultAdapter', NULL, NULL, NULL, E'IDP', NULL, 0, E'1', E'no', E'n', E'read');
INSERT INTO mxk_apps (id, appname, loginurl, category, secret, protocol, icon, status, createdby, createddate, modifiedby, modifieddate, description, vendor, vendorurl, credential, sharedusername, sharedpassword, systemuserattr, isextendattr, extendattr, sortindex, issignature, visible, isadapter, adapterid, adaptername, adapter, principal, credentials, userpropertys, inducer, logouturl, logouttype, instid, frequently, resourcemgt, openapiright) VALUES (E'816077428370702336', E'CAS Demo', E'http://cas.demo.maxkey.top:9521/demo-cas/', E'none', E'$2a$10$2xMbT.QffmAOOj4ZaoPOCueb402205e684ce6f1710bb232a01112b89794b0b9af1044605b213471866cd40', E'CAS', NULL, 1, E'admin', E'2014-09-16 13:56:03', NULL, NULL, E'', E'MaxKey', E'https://github.com/shimingxy/MaxKey', E'none', NULL, NULL, NULL, E'0', NULL, 302, 0, 1, 1, E'622227747946762291', E'CAS默认适配器', E'org.dromara.maxkey.authz.cas.adapter.CasDefaultAdapter', NULL, NULL, NULL, E'IDP', E'http://cas.demo.maxkey.top:9521/demo-cas//index.jsp', 1, E'1', E'no', E'n', E'read');
INSERT INTO mxk_apps (id, appname, loginurl, category, secret, protocol, icon, status, createdby, createddate, modifiedby, modifieddate, description, vendor, vendorurl, credential, sharedusername, sharedpassword, systemuserattr, isextendattr, extendattr, sortindex, issignature, visible, isadapter, adapterid, adaptername, adapter, principal, credentials, userpropertys, inducer, logouturl, logouttype, instid, frequently, resourcemgt, openapiright) VALUES (E'817568547575169024', E'云速邮箱', E'https://www.cndnsapi.com/email/clientmanagement', E'1012', E'$2a$10$/y6dG71CUPxK6hnqFQHjde973eeee88135d26d421b7ba968fe06a46de949ac227d7527158bd72aed31a063dad3d3d466ba7516d56839ab93fbeba74bbe2917f5a67cbf', E'Extend_API', NULL, 1, NULL, NULL, NULL, NULL, E'邮箱', E'华为', E'https://www.huaweicloud.com/theme/244096-1-Y', E'system', E'', E'', E'username', E'1', E'[{"attr":"action","type":"String","value":"md5"}]', 10, 0, 1, 1, NULL, E'云速邮箱适配器', E'org.dromara.maxkey.authz.exapi.endpoint.adapter.ExtendApiCndnsApiMailAdapter', E'a6e7288a21ab14c42c76c3708518628b', E'a61d4ed6b323c9f6aeabd2af65d65185', NULL, E'IDP', NULL, 0, E'1', E'no', E'n', E'read');
INSERT INTO mxk_apps (id, appname, loginurl, category, secret, protocol, icon, status, createdby, createddate, modifiedby, modifieddate, description, vendor, vendorurl, credential, sharedusername, sharedpassword, systemuserattr, isextendattr, extendattr, sortindex, issignature, visible, isadapter, adapterid, adaptername, adapter, principal, credentials, userpropertys, inducer, logouturl, logouttype, instid, frequently, resourcemgt, openapiright) VALUES (E'817568793663373312', E'JWT HS256', E'http://www.maxkey.org/jwt', E'none', E'$2a$10$N2fXXj7WTo7thbt0U5GmsO55ebd0c61866558eef4bc7bfe4c5318337ffef4d2127bacc63040051a24cb1a72669f89c30bb1d9b360632138c9ae1eee7103b1622f4252d', E'JWT', NULL, 1, NULL, NULL, NULL, NULL, NULL, NULL, NULL, E'none', NULL, NULL, NULL, E'0', NULL, 1, 0, 1, 0, NULL, NULL, NULL, NULL, NULL, NULL, E'IDP', NULL, 0, E'1', E'no', E'n', E'read');
INSERT INTO mxk_apps (id, appname, loginurl, category, secret, protocol, icon, status, createdby, createddate, modifiedby, modifieddate, description, vendor, vendorurl, credential, sharedusername, sharedpassword, systemuserattr, isextendattr, extendattr, sortindex, issignature, visible, isadapter, adapterid, adaptername, adapter, principal, credentials, userpropertys, inducer, logouturl, logouttype, instid, frequently, resourcemgt, openapiright) VALUES (E'820821184445677568', E'禅道项目管理', E'http://zentao.maxkey.top:9530/zentao/', E'1111', E'$2a$10$QepCWkE/JYwEelzhF24op.abcc854948d28a184b1937fa112bc97aed37d222f02137355b28e690a6bc1895e0b77c8b824f8e0366112f5f59acf83cb43539d479ce0923', E'Extend_API', NULL, 1, NULL, NULL, NULL, NULL, E'项目管理', E'禅道', E'https://www.zentao.net/', E'system', E'', E'', E'username', E'0', NULL, 5, 0, 1, 1, NULL, E'禅道项目管理适配器', E'org.dromara.maxkey.authz.exapi.endpoint.adapter.ExtendApiZentaoAdapter', E'maxkey', E'f71792dfebf23d62bc4d65d1513087e3', NULL, E'IDP', NULL, 0, E'1', E'no', E'n', E'read');
INSERT INTO mxk_apps (id, appname, loginurl, category, secret, protocol, icon, status, createdby, createddate, modifiedby, modifieddate, description, vendor, vendorurl, credential, sharedusername, sharedpassword, systemuserattr, isextendattr, extendattr, sortindex, issignature, visible, isadapter, adapterid, adaptername, adapter, principal, credentials, userpropertys, inducer, logouturl, logouttype, instid, frequently, resourcemgt, openapiright) VALUES (E'820821835145805824', E'腾讯企业邮箱', E'https://exmail.qq.com/cgi-bin/login', E'1012', E'$2a$10$EWTHQDHcNSYAHn3fwo/you0940ab9dff2453aa410d8b1ba1f8c650df3d54106fc68ee7f9ea28d52f4e849dd779bd412e35a0d75c3c3479d0af90863711a9d556288835', E'Extend_API', NULL, 1, E'admin', E'2015-01-20 15:46:06', NULL, NULL, E'', E'腾讯', E'http://exmail.qq.com/', E'user_defined', E'', E'', E'username', E'0', NULL, 9, 0, 1, 1, E'', E'腾讯企业邮箱适配器', E'org.dromara.maxkey.authz.exapi.endpoint.adapter.ExtendApiQQExmailAdapter', E'wwbe67871bc756a7be', E'gBTaSj1ozswHN7qInC2V-GSB80-80R8NjZMAGlPWm4A', NULL, E'IDP', E'', 0, E'1', E'no', E'n', E'read');
INSERT INTO mxk_apps (id, appname, loginurl, category, secret, protocol, icon, status, createdby, createddate, modifiedby, modifieddate, description, vendor, vendorurl, credential, sharedusername, sharedpassword, systemuserattr, isextendattr, extendattr, sortindex, issignature, visible, isadapter, adapterid, adaptername, adapter, principal, credentials, userpropertys, inducer, logouturl, logouttype, instid, frequently, resourcemgt, openapiright) VALUES (E'820822501587156992', E'JWT Demo', E'http://tokenbased.demo.maxkey.top:9521/demo-jwt/', E'none', E'$2a$10$qZ5ox2qSAP1l0Cigzgofeu3275b26ec7bf2794b7d46d6225036c251fbabd92a05b7576b85095cee4b2e764', E'JWT', NULL, 1, E'admin', E'2016-10-13 14:29:10', NULL, NULL, E'Test', E'MaxKey', E'https://github.com/shimingxy/MaxKey', E'none', NULL, NULL, NULL, E'0', NULL, 304, 0, 1, 1, E'', E'JWT适配器', E'org.dromara.maxkey.authz.jwt.endpoint.adapter.JwtAdapter', NULL, NULL, E'userId,username,email,employeeNumber,departmentId,department,windowsAccount', E'IDP', E'', 0, E'1', E'no', E'n', E'read');
INSERT INTO mxk_apps (id, appname, loginurl, category, secret, protocol, icon, status, createdby, createddate, modifiedby, modifieddate, description, vendor, vendorurl, credential, sharedusername, sharedpassword, systemuserattr, isextendattr, extendattr, sortindex, issignature, visible, isadapter, adapterid, adaptername, adapter, principal, credentials, userpropertys, inducer, logouturl, logouttype, instid, frequently, resourcemgt, openapiright) VALUES (E'822180682301177856', E'SpringBoot SAML 2.0SP', E'http://sso.maxkey.top:8080/', E'none', E'$2a$10$dMGtfR4CLY4NLyTzTGCvQe0d9d423e99f4e0c5270c93f8ce53cf70b9c02eb6f97394ee8513d5dc5d72ae62a8f79cf8634640f4f8f163a60d2e6e993a029597c94ddca4', E'SAML_v2.0', NULL, 1, NULL, NULL, NULL, NULL, E'', E'SpringBoot', E'https://github.com/vdenotaris/spring-boot-security-saml-sample', E'none', NULL, NULL, NULL, E'0', NULL, 308, 0, 1, 1, NULL, NULL, E'', NULL, NULL, NULL, E'IDP', NULL, NULL, E'1', E'no', E'n', E'read');
INSERT INTO mxk_apps (id, appname, loginurl, category, secret, protocol, icon, status, createdby, createddate, modifiedby, modifieddate, description, vendor, vendorurl, credential, sharedusername, sharedpassword, systemuserattr, isextendattr, extendattr, sortindex, issignature, visible, isadapter, adapterid, adaptername, adapter, principal, credentials, userpropertys, inducer, logouturl, logouttype, instid, frequently, resourcemgt, openapiright) VALUES (E'823620386997403648', E'阿里云用户SSO', E'https://www.aliyun.com/', E'none', E'$2a$10$blG3l5OX3sgBC0.HlYjhDO0d9813dbd6024c3cb07b5c549fc6b028aa9a0d551885240b6d61a99819136d1404523a326b3df2bc4ff6829ad2960d414cad7baad8e46021', E'SAML_v2.0', NULL, 1, NULL, NULL, NULL, NULL, E'', E'阿里云', E'https://www.aliyun.com/', E'none', NULL, NULL, NULL, E'0', NULL, 6, 0, 1, 0, NULL, NULL, E'', NULL, NULL, NULL, E'IDP', NULL, 0, E'1', E'no', E'n', E'read');
INSERT INTO mxk_apps (id, appname, loginurl, category, secret, protocol, icon, status, createdby, createddate, modifiedby, modifieddate, description, vendor, vendorurl, credential, sharedusername, sharedpassword, systemuserattr, isextendattr, extendattr, sortindex, issignature, visible, isadapter, adapterid, adaptername, adapter, principal, credentials, userpropertys, inducer, logouturl, logouttype, instid, frequently, resourcemgt, openapiright) VALUES (E'823720999999504384', E'SalesForce     ', E'https://login.salesforce.com/', E'1912', E'$2a$10$yY6DRnkFTfZ3hJ5LOCNJKe4ab4d3f700703f3f3fd7d4eb28e46b75b6f61f554a5a0e07cba1a47363b02d95a88dac9cac37c380fdbf8514326a661b83eb2892285e2262', E'SAML_v2.0', NULL, 1, E'superadmin', E'2013-05-23 13:50:19', E'admin', E'2016-11-06 16:37:22', E'CRM', E'SalesForce', E' http://www.salesforce.com', E'none', NULL, NULL, NULL, E'0', NULL, 13, 0, 1, 0, NULL, NULL, E'', NULL, NULL, NULL, E'IDP', NULL, 0, E'1', E'no', E'n', E'read');
INSERT INTO mxk_apps (id, appname, loginurl, category, secret, protocol, icon, status, createdby, createddate, modifiedby, modifieddate, description, vendor, vendorurl, credential, sharedusername, sharedpassword, systemuserattr, isextendattr, extendattr, sortindex, issignature, visible, isadapter, adapterid, adaptername, adapter, principal, credentials, userpropertys, inducer, logouturl, logouttype, instid, frequently, resourcemgt, openapiright) VALUES (E'824007723908595712', E'腾讯云', E'https://cloud.tencent.com/', E'none', E'$2a$10$syVUzfS308j8q72p28QisO95d0261bcb27d003ce489d4898aff71699050205e62dcbd3c5e409038c79bc6f1cd55645805241f95c651f324158e295b91842079b582a37', E'SAML_v2.0', NULL, 1, NULL, E'2020-02-27 14:35:46', NULL, NULL, E'腾讯云', E'腾讯', E'https://console.cloud.tencent.com/', E'none', NULL, NULL, NULL, E'1', E'[{"attr":"https://cloud.tencent.com/SAML/Attributes/Role","type":"UNSPECIFIED","value":"qcs::cam::uin/100013138092:roleName/cloud.tencent_maxkey#44;qcs::cam::uin/100013138092:saml-provider/maxkey"},{"attr":"https://cloud.tencent.com/SAML/Attributes/RoleSessionName","type":"UNSPECIFIED","value":"maxkey"}]', 7, 0, 1, 0, NULL, NULL, E'', NULL, NULL, NULL, E'IDP', NULL, 0, E'1', E'no', E'n', E'read');
INSERT INTO mxk_apps (id, appname, loginurl, category, secret, protocol, icon, status, createdby, createddate, modifiedby, modifieddate, description, vendor, vendorurl, credential, sharedusername, sharedpassword, systemuserattr, isextendattr, extendattr, sortindex, issignature, visible, isadapter, adapterid, adaptername, adapter, principal, credentials, userpropertys, inducer, logouturl, logouttype, instid, frequently, resourcemgt, openapiright) VALUES (E'824007893782102016', E'华为云', E'https://auth.huaweicloud.com/authui/federation/websso?domain_id=0bc9765dc180f4f90f06c01901a87060&idp=MaxKey&protocol=saml', E'none', E'$2a$10$.0venZ8PcoXzBGZ2/bvWGe75a0b505ba6128d708333a98a9b7e544b8ba258567d55ea3c712d8b3ccd8059d6f33a7eda7f98d4a4e313030bd4eaf5054fef97466387b31', E'SAML_v2.0', NULL, 1, NULL, NULL, NULL, NULL, E'', E'华为', E'https://www.huaweicloud.com/', E'none', NULL, NULL, NULL, E'0', E'[]', 2, 0, 1, 0, NULL, NULL, E'', NULL, NULL, NULL, E'SP', NULL, 0, E'1', E'no', E'n', E'read');
INSERT INTO mxk_apps (id, appname, loginurl, category, secret, protocol, icon, status, createdby, createddate, modifiedby, modifieddate, description, vendor, vendorurl, credential, sharedusername, sharedpassword, systemuserattr, isextendattr, extendattr, sortindex, issignature, visible, isadapter, adapterid, adaptername, adapter, principal, credentials, userpropertys, inducer, logouturl, logouttype, instid, frequently, resourcemgt, openapiright) VALUES (E'824008507220033536', E'CAS SpringBoot', E'http://127.0.0.1:8989/test1/index', E'none', E'$2a$10$Ccakf/cYgQcVtZs/oX2hd.16f09019428e19a54d905ce22e6958e70bb9585940fa20501303fead41d2bfe02322e65e8b3e229f9e296f4d65a7fed6dce198f3190cc66f', E'CAS', NULL, 1, NULL, NULL, NULL, NULL, NULL, NULL, NULL, E'none', NULL, NULL, NULL, E'0', NULL, 1, 0, 1, 1, E'622227747946762291', E'CAS默认适配器', E'org.dromara.maxkey.authz.cas.adapter.CasDefaultAdapter', NULL, NULL, NULL, E'IDP', NULL, 0, E'1', E'no', E'n', E'read');
INSERT INTO mxk_apps (id, appname, loginurl, category, secret, protocol, icon, status, createdby, createddate, modifiedby, modifieddate, description, vendor, vendorurl, credential, sharedusername, sharedpassword, systemuserattr, isextendattr, extendattr, sortindex, issignature, visible, isadapter, adapterid, adaptername, adapter, principal, credentials, userpropertys, inducer, logouturl, logouttype, instid, frequently, resourcemgt, openapiright) VALUES (E'824009331925057536', E'阿里云', E'https://www.aliyun.com', E'none', E'$2a$10$ywLDisVoXFkW/Qvod3o8N.2786c01d77da39b7c7f9972407a6e6167d3ef255302eb3da17bc8cc358ce9347bf49d51ff16be5fecca4d20d32b9b4c845303c9ffe3fb538', E'SAML_v2.0', NULL, 1, NULL, E'2020-02-28 01:42:20', NULL, NULL, E'阿里云', E'阿里', E'https://www.aliyun.com', E'none', NULL, NULL, NULL, E'1', E'[{"id":"1","attr":"https://www.aliyun.com/SAML-Role/Attributes/RoleSessionName","type":"UNSPECIFIED","value":"2037230828547234327"},{"id":"2","attr":"https://www.aliyun.com/SAML-Role/Attributes/Role","type":"UNSPECIFIED","value":"acs:ram::1729982683323703:role/maxkey,acs:ram::1729982683323703:saml-provider/maxkey"},{"id":"3","attr":"https://www.aliyun.com/SAML-Role/Attributes/SessionDuration","type":"UNSPECIFIED","value":"1800"}]', 2, 0, 1, 0, NULL, NULL, E'', NULL, NULL, NULL, E'IDP', NULL, 0, E'1', E'no', E'n', E'read');
INSERT INTO mxk_apps (id, appname, loginurl, category, secret, protocol, icon, status, createdby, createddate, modifiedby, modifieddate, description, vendor, vendorurl, credential, sharedusername, sharedpassword, systemuserattr, isextendattr, extendattr, sortindex, issignature, visible, isadapter, adapterid, adaptername, adapter, principal, credentials, userpropertys, inducer, logouturl, logouttype, instid, frequently, resourcemgt, openapiright) VALUES (E'824009611043405824', E'LTPA-Cookie', E'http://tokenbased.demo.maxkey.top:9521/demo-ltpa/ltpa.jsp', E'none', E'$2a$10$ruK/JO8gKfECnrdzWxk73.583e94467745144eca54731740b327f38645f25bece77c5c9421f58081c765d1', E'Token_Based', NULL, 1, NULL, E'2019-11-09 10:13:11', NULL, NULL, E'Test', E'MaxKey', E'https://github.com/shimingxy/MaxKey', E'none', NULL, NULL, NULL, E'0', NULL, 307, 0, 1, 1, NULL, E'令牌默认默认适配器', E'org.dromara.maxkey.authz.token.endpoint.adapter.TokenBasedDefaultAdapter', NULL, NULL, E'userId,username,email,employeeNumber,departmentId,department,windowsAccount', E'IDP', NULL, 0, E'1', E'no', E'n', E'read');
INSERT INTO mxk_apps (id, appname, loginurl, category, secret, protocol, icon, status, createdby, createddate, modifiedby, modifieddate, description, vendor, vendorurl, credential, sharedusername, sharedpassword, systemuserattr, isextendattr, extendattr, sortindex, issignature, visible, isadapter, adapterid, adaptername, adapter, principal, credentials, userpropertys, inducer, logouturl, logouttype, instid, frequently, resourcemgt, openapiright) VALUES (E'824010355507200000', E'Token_Based_Json', E'http://tokenbased.demo.maxkey.top:9521/demo-tokenbase/', E'none', E'$2a$10$vvuCfYOPpgyAiK/0des9pece9d58c33de50e6e330ce95f38d47e188a5ab40e01407dd37976c4f2c56cb529', E'Token_Based', NULL, 1, E'superadmin', E'2013-05-25 03:45:54', NULL, NULL, E'Test', E'MaxKey', E'https://github.com/shimingxy/MaxKey', E'none', NULL, NULL, NULL, E'0', NULL, 5, 0, 1, 0, E'', E'', E'', NULL, NULL, E'userId,username,email,employeeNumber,departmentId,department,windowsAccount', E'IDP', E'', 0, E'1', E'no', E'n', E'read');
INSERT INTO mxk_apps (id, appname, loginurl, category, secret, protocol, icon, status, createdby, createddate, modifiedby, modifieddate, description, vendor, vendorurl, credential, sharedusername, sharedpassword, systemuserattr, isextendattr, extendattr, sortindex, issignature, visible, isadapter, adapterid, adaptername, adapter, principal, credentials, userpropertys, inducer, logouturl, logouttype, instid, frequently, resourcemgt, openapiright) VALUES (E'824012456819949568', E'Token_Based_Simple', E'http://tokenbased.demo.maxkey.top:9521/demo-tokenbase/sampletoken.jsp', E'none', E'$2a$10$67xkagBJmJ7GOq44ccSPU.9f87327f5460008235ebf5276f2023a8f71158552fcfab0307e3469e99669dba', E'Token_Based', NULL, 1, E'admin', E'2014-12-14 16:14:35', NULL, NULL, E'', E'MaxKey', E'https://github.com/shimingxy/MaxKey', E'none', NULL, NULL, NULL, E'0', NULL, 305, 0, 1, 1, E'', E'简单令牌适配器', E'org.dromara.maxkey.authz.token.endpoint.adapter.TokenBasedSimpleAdapter', NULL, NULL, E'username', E'IDP', E'', 0, E'1', E'no', E'n', E'read');
INSERT INTO mxk_apps_adapters (id, name, protocol, adapter, sortindex, createdby, createddate, modifiedby, modifieddate, description) VALUES (E'622227747946762290', E'OAuth 2.0默认适配器', E'OAuth_v2.0', E'org.dromara.maxkey.authz.oauth2.provider.userinfo.endpoint.OAuthDefaultUserInfoAdapter', 1, E'MaxKey', E'2021-03-25 11:42:47', E'MaxKey', NULL, E'');
INSERT INTO mxk_apps_adapters (id, name, protocol, adapter, sortindex, createdby, createddate, modifiedby, modifieddate, description) VALUES (E'622227747946762291', E'CAS默认适配器', E'CAS', E'org.dromara.maxkey.authz.cas.adapter.CasDefaultAdapter', 2, E'MaxKey', E'2021-03-25 11:36:05', E'MaxKey', NULL, E'');
INSERT INTO mxk_apps_adapters (id, name, protocol, adapter, sortindex, createdby, createddate, modifiedby, modifieddate, description) VALUES (E'622227747946762292', E'令牌默认适配器', E'Token_Based', E'org.dromara.maxkey.authz.token.endpoint.adapter.TokenBasedDefaultAdapter', 3, E'MaxKey', E'2021-03-25 11:35:33', E'MaxKey', NULL, E'');
INSERT INTO mxk_apps_adapters (id, name, protocol, adapter, sortindex, createdby, createddate, modifiedby, modifieddate, description) VALUES (E'622227747946762293', E'简单令牌适配器', E'Token_Based', E'org.dromara.maxkey.authz.token.endpoint.adapter.TokenBasedSimpleAdapter', 4, E'MaxKey', E'2021-03-25 11:38:21', E'MaxKey', NULL, E'');
INSERT INTO mxk_apps_adapters (id, name, protocol, adapter, sortindex, createdby, createddate, modifiedby, modifieddate, description) VALUES (E'622227747946762294', E'JWT适配器', E'JWT', E'org.dromara.maxkey.authz.jwt.endpoint.adapter.JwtAdapter', 5, E'MaxKey', E'2021-03-25 11:36:48', E'MaxKey', NULL, E'');
INSERT INTO mxk_apps_adapters (id, name, protocol, adapter, sortindex, createdby, createddate, modifiedby, modifieddate, description) VALUES (E'622227747946762295', E'腾讯企业邮箱适配器', E'Extend_API', E'org.dromara.maxkey.authz.exapi.endpoint.adapter.ExtendApiQQExmailAdapter', 101, E'MaxKey', E'2021-03-25 11:38:39', E'MaxKey', NULL, E'');
INSERT INTO mxk_apps_adapters (id, name, protocol, adapter, sortindex, createdby, createddate, modifiedby, modifieddate, description) VALUES (E'622227747946762296', E'网易有道云适配器', E'Form_Based', E'org.dromara.maxkey.authz.formbased.endpoint.adapter.FormBasedNeteaseNoteYoudaoAdapter', 102, E'MaxKey', E'2021-03-25 11:37:59', E'MaxKey', NULL, E'');
INSERT INTO mxk_apps_adapters (id, name, protocol, adapter, sortindex, createdby, createddate, modifiedby, modifieddate, description) VALUES (E'622227747946762297', E'云速邮箱适配器', E'Extend_API', E'org.dromara.maxkey.authz.exapi.endpoint.adapter.ExtendApiCndnsApiMailAdapter', 103, E'MaxKey', E'2021-03-25 11:37:24', E'MaxKey', NULL, E'');
INSERT INTO mxk_apps_adapters (id, name, protocol, adapter, sortindex, createdby, createddate, modifiedby, modifieddate, description) VALUES (E'622227747946762298', E'禅道项目管理适配器', E'Extend_API', E'org.dromara.maxkey.authz.exapi.endpoint.adapter.ExtendApiZentaoAdapter', 104, E'MaxKey', E'2021-03-25 11:36:29', E'MaxKey', NULL, E'禅道11.5.1版本开始');
INSERT INTO mxk_apps_adapters (id, name, protocol, adapter, sortindex, createdby, createddate, modifiedby, modifieddate, description) VALUES (E'622227747946762299', E'网易企业邮箱', E'Extend_API', E'org.dromara.maxkey.authz.exapi.endpoint.adapter.ExtendApiQiye163ExmailAdapter', 105, E'MaxKey', E'2022-03-03 11:36:29', E'MaxKey', NULL, NULL);
INSERT INTO mxk_apps_adapters (id, name, protocol, adapter, sortindex, createdby, createddate, modifiedby, modifieddate, description) VALUES (E'622227747946762300', E'CAS明文适配器', E'CAS', E'org.dromara.maxkey.authz.cas.adapter.CasPlainAdapter', 6, E'MaxKey', E'2021-03-25 11:36:05', E'MaxKey', NULL, E'');
INSERT INTO mxk_apps_cas_details (id, service, callbackurl, expires, instid, casuser) VALUES (E'622076759805923328', E'http://mgt.maxkey.top/maxkey-mgt/passport/trust/auth', E'http://mgt.maxkey.top/maxkey-mgt/passport/trust/auth', 300, E'1', E'username');
INSERT INTO mxk_apps_cas_details (id, service, callbackurl, expires, instid, casuser) VALUES (E'622227747938373638', E'http://hr.maxkey.top', E'http://hr.maxkey.top', 300, E'1', E'username');
INSERT INTO mxk_apps_cas_details (id, service, callbackurl, expires, instid, casuser) VALUES (E'807667697885118464', E'http://jump.maxkey.top/', E'http://jump.maxkey.top/core/auth/cas/login/?next=%2F', 180, E'1', E'username');
INSERT INTO mxk_apps_cas_details (id, service, callbackurl, expires, instid, casuser) VALUES (E'807671808701497344', E'http://localhost:8080/jenkins/securityRealm/finishLogin', E'http://localhost:8080/jenkins/securityRealm/finishLogin', 180, E'1', E'username');
INSERT INTO mxk_apps_cas_details (id, service, callbackurl, expires, instid, casuser) VALUES (E'808307337319153664', E'http://weaver.demo.maxkey.top:8080/weaver/', E'http://weaver.demo.maxkey.top:8080/weaver/Login.jsp', 180, E'1', E'username');
INSERT INTO mxk_apps_cas_details (id, service, callbackurl, expires, instid, casuser) VALUES (E'808321992456404992', E'http://app1.cas.com:8081/callback?client_name=pac4jclient1', E'http://app1.cas.com:8081/callback?client_name=pac4jclient1&', 180, E'1', E'username');
INSERT INTO mxk_apps_cas_details (id, service, callbackurl, expires, instid, casuser) VALUES (E'816077086090330112', E'http://cas-backend.demo.maxkey.top:9521/demo-cas-backend/', E'http://cas-backend.demo.maxkey.top:9521/demo-cas-backend/', 180, E'1', E'username');
INSERT INTO mxk_apps_cas_details (id, service, callbackurl, expires, instid, casuser) VALUES (E'816077428370702336', E'http://cas.demo.maxkey.top:9521/demo-cas/', E'http://cas.demo.maxkey.top:9521/demo-cas/', 180, E'1', E'username');
INSERT INTO mxk_apps_cas_details (id, service, callbackurl, expires, instid, casuser) VALUES (E'824008507220033536', E'http://127.0.0.1:8989/test1/index', E'http://127.0.0.1:8989/test1/index', 300, E'1', E'username');
INSERT INTO mxk_apps_jwt_details (id, issuer, subject, audience, algorithmkey, algorithm, encryptionmethod, signature, signaturekey, expires, redirecturi, jwtname, tokentype, instid) VALUES (E'817568793663373312', NULL, E'username', NULL, E'', E'NONE', E'A128GCM', E'HS256', E'{"kty":"oct","use":"sig","kid":"817568793663373312_sig","k":"b9erZxWvhlTXkL1vwCgE1iulTbN1dCQghGbMqWXWu6zulfkW8tyIeuauwnU6O-CTQ2lmdl3ed7SXJPitU8-CwSFXYD5bxeYm1iHd22lw2RoWUYLdfVBOFQIroLmNryEz3S0rCtFUsxoWXDctcCJILsIPV0ZpheJuRmjoZJjZiY225x5tyuzS7OxwiXfRWg6GZY2OubRWqvYHsya5ghsbc52xD_k0WIovKE9L9AV_NDxVZDtMENQ7tGwa_h_1LQgDTmUsBi4osxaSftgU9_2nnaYNFfSKp4y3dvALHhXOMpd5Bx3qQdRasuPbPEKCoBn5HrcB7aPHC6jZF2bpQ4ZWVA","alg":"HS256"}', 300, E'http://www.maxkey.org/jwt', E'jwt', E'POST', E'1');
INSERT INTO mxk_apps_jwt_details (id, issuer, subject, audience, algorithmkey, algorithm, encryptionmethod, signature, signaturekey, expires, redirecturi, jwtname, tokentype, instid) VALUES (E'820822501587156992', E'http://sso.maxkey.top/maxkey', E'username', E'http://sso.maxkey.top:9527/maxkey-mgt', E'', E'NONE', E'A128GCM', E'RS256', E'{"kty":"RSA","d":"K2VCm_6enq5uoFLZXUlWkgbCXj5m9X5uUX3_Ol3qcY9X1cP04TN98R8lpw-ASeFDRFRhe0FT-lYCYu_fqZcrNXVhyN3rgi27af5x4HdFMnHLTLMPvE6aEyTGmZjTF1AbiX5VOJAl6POI9FiyTbV1Uqt943ydJv8SH4NfcYhKBmpp8Fi1f58mon-bYwsIy8mzZjssc8KZy-GzpscKrc5ewb7106JY3uRQNprAHrpcGAPZ8uXUvVhrxp_FNn5Nf5KVxl2tm50L83_5nw0OZrbJ8Ceg7sZAw_Z41lbYbS9VDaST6TuKRb7W4XCKimZUn57LoQT2-Gkv6msJHCmqTgK02Q","e":"AQAB","use":"sig","kid":"820822501587156992_sig","alg":"RS256","n":"vyfZwQuBLNvJDhmziUCFuAfIv-bC6ivodcR6PfanTt8XLd6G63Yx10YChAdsDACjoLz1tEU56WPp_ee_vcTSsEZT3ouWJYghuGI2j4XclXlEj0S7DzdpcBBpI4n5dr8K3iKY-3JUMZR1AMBHI50UaMST9ZTZJAjUPIYxkhRdca5lWBo4wGUh1yj_80-Bq6al0ia9S5NTzNLaJ18jSxFqZ79BAkBm-KjkP248YUk6WBGtYEAV5Fws4dpse4hrqJ3RRHiMZV1o1iTmPHz_l55ZSDP3vpYf6iKqKzoK2RmdjfH5mGpbc4-PclTs4GKfwZ7cWfrny6B7sMnQfzujCH996Q"}', 180, E'http://tokenbased.demo.maxkey.top:9521/demo-jwt/jwtcallback.jsp', E'jwt', E'POST', E'1');
INSERT INTO mxk_apps_jwt_details (id, issuer, subject, audience, algorithmkey, algorithm, encryptionmethod, signature, signaturekey, expires, redirecturi, jwtname, tokentype, instid) VALUES (E'943648578755100672', NULL, E'username', NULL, E'{"p":"yK7Jsf5A5rnhfCptsazR4gec7phxF2imKd466iKYclNPfy_tZzM2PXXCachmf7_AMkO_8yyNsfG8lrUv5MxX0glpz47RlO_dqZ5Cmt-5Hm0MI--DBTmsRlHu3Bxts50vE3eWIqNQquP-ORCJagBKn7TXPsfKlku3VD0PlAgxpq8","kty":"RSA","q":"xvbTyI3sS-wtVVWfVesg6Pb5w2hRyrPHuLODVVJToN6cVkm3-TebGxqizrimIS0SlMo-NMPLsSobSVhHK51ShCZFMEPASYicZXb5-sduHH-VhnKP3GpWSLrs99-CePD90-8UAfJo5mRYHQSZ3uTbC7gyRK1lLbJFfSG-LKP-nfc","d":"Gkdh-Ng18w_7Ayj5AkSnQNTZPU-Yz13aCqVog4AuCdUMd_BRXB-n729jcI3JSS5_yR7cKjyz4exQ0SP205HYkOut9gj5TkNNPSSMnVewi6lX8J2wsgnbr-dZc75u7LRy1VU0oB92O3NNgqOpmaz4QsgsrVyjsgLVryq227rQIEz0JUtid8qg0OnLHQ2063WqpRc7UCbQtWzgB295wpkERNS9TAaizZo1MZNUpkYNtSEQmymVzKZrG0bnOVkKvCOdSPGgcQ3j28LltQInrLE1rM_YttAcUhISryMT6V7ev9-K3JcpWGvdUtsqwzeBCyqYnUFTuXx-Z12qAawftGyk6Q","e":"AQAB","use":"enc","kid":"943648578755100672_enc","qi":"qBvFVIYYOnzbddcRlPadKMO66uONQKG3lrSeuKOLYmAYY7FsElehNPfV2fXC9lnu7Uo7sus1Mb58FQANTy-k-xcW195Sebwk3xwKIwlaCG5e1XXdGjMeWH8m_LynE9xnRYgkwa4ospKQ2A2gaB4ppkdZGWTnMlOogfd4ypup-34","dp":"V7b2F6Ne8LoMUX4mBgPYlOfo8uyUebvW7PPiYlYOteGuHJRxOqtKqOBgwmXCT1IbipzMOFif8kgLuv-k2GdsdzSAGCV_e47AHxQ6XoEs45ycMtTMOqtzniTPt0uBs4Efg23ApJEngBo5Eu4kcb2A4H9lmV4wMTMVBW_O8FAIi6c","alg":"RSA1_5","dq":"kcyka24c_5HlsofZCCQSbMU3R8u1TD4sGBxsHGUE5XjbxZul1lm6LsV5EtVa4CrgV-pQZWgpZv09G6U2Gi7iHfbRcsnjKb-TJANosi3cccPItcpTw6ik7A0Ww5mlSa0HxHuJBNg3qMVVkIYjn6PDJLZpF8ycvTzLESRd8OaIGgc","n":"m_it-sO9TizuxwNLy3TuFwBHpJS00BIGChh2ieptkZ88cOECd78tpt0-dPg01ggXLOZLmx9ZCrc4ABxgb3w5YCCeEDRJzQJCsCYQFltL-5epbeJyhhBcl5o01sachRAUQgeOnRkj0UvVqg9mXblJZTt6ZuArXpqV0P3eHW-yus2XrKb6jTjZtBNFNYJvEYo8DuhQJr1uhSpz5SYAcZoF4jy_7n4rDYBnuLOiihuDLxoKJ69x2wZV7t26r3uEdDL4lNWQRqM7YoQEC4rey6pqOHqooup5dH3S0pFuWt9YWCm4tgxByYvjgq4aUpUIUces_77WMqcpZYehXRdTKcMl2Q"}', E'RSA1_5', E'A192GCM', E'RS256', E'{"p":"wEC3ddDXhZsS33O-KvsxbqKEpkRJVgM1LET3c_6jLH2W0dpQ2EMza2TBCi2xmOAcGVh2GmQbONtG3srQyrCBYNomU4RkQ1ZGOxXqs75P_36z4IsiKX8NCnog1ZroXSfFA1yP393KQHtWFBOza9ydI-wan9nGhFmkDxgiiuiZswE","kty":"RSA","q":"y_v58pLV9mVxL_zj_nR0pVeqPie3yEjOWXziqGi40UrqMVpsTR35u-Uq9_RdVEEli0FZJYcmITcBaknjMLKdKW3Dt9RxGpiOxK2-S8bmmLjlS_g5-nxK2ultuGX3c4jRsslhzqEmUgjMfvE_Qutzfu0B-kq4x20O5y0cLm6CHHs","d":"FoDhSBMCVPLgyeJMmrrf-aI7YT6iili4ScIVSD1TpWnqZqq3gEh-Fgredvw_UNoNHjDjHllGwAqMUWyyoAEQnOJ6OapXFfxLOfoz2fUMd7nqK7CX_cfgRDhbyVcupP-NUEhMnltZZinxYFv6sSrNGdVYOa9AXYrLDXIju-UaYkAxEOELdXLyeQr43AEoQXAlOyUFtXSb6TWpEfzRvk3IaQ_Fok71OlZqXNVeU3uoFCdVEq9WlYr5VpLebHDUZPQAVZhrDqgsFzKEntqv2x5KQASguub5A4MVLA7JbEs2oRwySgvk26uUBQ_KfRLHRUlDepc5JdHLaMRNMttGNSZUAQ","e":"AQAB","use":"sig","kid":"943648578755100672_sig","qi":"FZcFU0gC9KPe8L0OHOnzPFZBxbOVuHjAMKKvg6zhL_N8egzro84WN9y4o2rVRQ2vGz1velotSTN2qCa1_ncOxmaZyZ8B34fgFl4muaZ_2C3UWdqqxsMU_FEJMKyr5YUdl1tFTtwrza3BaC2FxPdKaZMLFR1LeaeUxx-f8edz9XQ","dp":"SPuIacpZNtgSxw8aPxjSwCwj7TZ5HJTlJ6QayEb_TNF0Yr_c9uwz5e3-tk14YQ-auyhw1T3xc5kSg1s8_eUZiFnoOMZGhaWHzcBZM9joZ5aC1Jgc5OHdYn_QXSaMVWjWipsl5xc8Q1RO7ho4f5bldJCZ3tr-WJnrBOvlmRQJ3QE","alg":"RS256","dq":"y6kb5-ZU-_pSZSAwHoj1QXPihMYxByYx6ET5JD3ScRxD8NygDurjwYbQPNpdKFcW_g9Ty1VBa544qn909tUOdyOhanQQLQauXI4_1faTm13Xid8fPAlGz4SKSLZ9tnufKstH_P8GfJdOXVvO1qiwGsTV2akrDenEHGn8nhs1ius","n":"mTCMo2sDR0c4qLRILXBf2OqzdRJOfLWrJvBkZfdGbrsWy4oHfWKS2XfwTrXfVw9HtqB3iFnoGmmqDqt1tdIaScrUcqPI6YXkH0YErytxdSb2PU25ysdzfvY7gKezLLanF9nEuDimZKxwYaSAe4cyD6Etnzr_b6RUh7drmwwrGHwqyHnJ2Xf7Nn-bsF0RV8NUAdSTnaY2r1QVMn0EiYZldQx0zgHTtXpbVXkT3YGgxfsIQ6FepWXgM6-k-oSHzKSKJWbF9Jm8A0CZVkOm_CrXos0Lz70tdgldU6L7AHvE5FtPH6NVUODJaroPVBS16Ntiy6PRrKsCPZIYOzlT5e8dew"}', 300, E'http://192.168.20.19/U9/mvc/login/index', E'jwt', E'POST', E'1');
INSERT INTO mxk_apps_jwt_details (id, issuer, subject, audience, algorithmkey, algorithm, encryptionmethod, signature, signaturekey, expires, redirecturi, jwtname, tokentype, instid) VALUES (E'943649050387808256', E'maxkey', E'username', NULL, E'{"p":"9g5VbBXznhWTmSVQ66R23jgDZqeLCwIvCczAA0FKCBQRwLns9bpaBv73GATxaz1_x80JOrVDUcMBKs7zB5rV4EnoofJiUicEr_uhRvYz4gtpoMYiUv_yok3CCggk2ragDW0ExOQlR1-mUrr3DGxJxd2p2MP6gjEUyDDoVIGCWBU","kty":"RSA","q":"wtLmoFH_2eWIp66FYLLype_zFa8cLK-5giBgz8D-tCuTCEUWpj12BfTjphNB-jsGnaHvv7lx86pPfybUIz6Rz0zgKlVi-lmFSe4YhkueLIYtWYa50lZUx7NpuUA3TCEVqzYMVoijCCY_3jx-PBCV--lFyykt8EhWg26jXlLGdfU","d":"BRozixmfrX4Z7Bf9yP4sVTXopdotFb_lhJ7mcDIagF0F9NoAflTgPlmTJFDy9dOeFmhZtu1g_Wk0ZGVuQ-5-tRwRpP01xgn_RbHwqQMWFZRS5ZzEjN3sEsLJ_rBgvRpNoa3ugSXzLsBoXKq_isgEMmdH6tM9jPE212g4fzWEOMoRJRIvnwOq2Bbj77utvbQ8RuAde43zPk1kX1CKfjMb4o6OI_UTrclM-jWuJLfMmkBYJX2K1H_paYT-NlURGQ6aa2oorUc42G8LX32Y0GeQfS5dLLFu2rtibmHAGtqUyvZyQH_lQjwf2kmbqsQjdmJJ7-iGqIComWyjMewXNYif3Q","e":"AQAB","use":"enc","kid":"943649050387808256_enc","qi":"FnySA6dfP7W5vERXo2q74TkC_geaG4sjwFvqISKd7JNg6C2nxrfkgjdZ-r0W4udHXeY1IRz3wE2_eGp4tQx_BatUF9zDShxwGlgUOmyCSXrDnHDHL3QSIxrGMjyiKSWVcX-SJwNyaUJBe9KaDNmEh_qUvw_tlsKq3fz3A9m4foE","dp":"YoF4h03-evJOZcg_ribog6xPCEDY9G5KYJT85hC0T6mhNdP5XqLdOeHHEHGiKPm090tJf5xjuA7mn7m8J_Y_24wbOwJrhFIkmUOW3G7idIN3JStNQIdBHuMcZKHAB2OHjfhwKVbg6cMMNiCtmOadXj6QqbxDxO1bUY3q5TH3-cU","alg":"RSA1_5","dq":"IKuZPR1DGFkjd2sOts6LXkREsUgyI1Q8eZPQaEZm7_O2rlZXm_0Gg60zV7A3Ci1HyLtVJwOEFmZi-mGahWaCsQ6lMLQs6uqELYed2TdpCPJfPHoZQypzASIXApfALiYGKjXgD8rN_Bnd7_iY-p2VaS8PIyh-qaKXz2aIQtMCsNk","n":"u0GSKPPRkaeuBxVzSu8YPxydg-YvzIg6RvM2vYYsuQGD6A2rG9QSYdCw4xc6R0J4NWRCjrm1ENYlt6aj1mRes885LAaPdurvbxisKkEGuccVdWWzCVmgHs1S9vxxCMlg8VnNw8iRdvaph8-TRJGl0R55OUIIswTzXbqHmxQYjtTzERdywYTZLZHhp_NTBs5mrSBKMBSbHQ0p3SGoJM_ckEYEvfYLsf6t8bDceL5a-iXm-ANhui84OnIQQZUN1lDaWQtmhgt9aMMBMYHvqbyucnXOQw4vLj6xU7wfHisAUlmuTrjoaJKQc4IMwDzeenkWbAGtUgTx7kDXzJnNXj3lGQ"}', E'RSA1_5', E'A128GCM', E'RS256', E'{"p":"-zPPrKLRhykt2EO_EDElIBvLa3nGnYDs4HC72b7VGHMpgR7-8M_B6ZvzSkvp5EsUKfOngLDVAc0FA6lrfL9GQMj4yzB2P84lz5X_mrg1E0PR3MMwJR1JPnjAg0JTNnGxxcqIxXsKh1jg1qdxpnYVJvKGMRjd4PAi6ieB-o1jL5c","kty":"RSA","q":"6NV83m3TaHUzqnJBeUQ7JyxsGrp35ETFQxMWiDPOvnKy4OQcyMELN8gF0hc7B4eT82XPhqR--rsDcyUBh9pWpXhUvlPYSun_TQH3yuNrm2FC1jVNQMKuNVjOST1JufpGKMsZQcoZZJlVod1o-lViK7-cUo3DThQbZEmNS2_jJZc","d":"a3v-GnAqotCWjQXbIL6DcBdAoIV0VxksjvV3wnwJgn9DGBuRbAvOEZUciQBkIckKrcFrCPsOGrpViMZk_8xBEWSA8OCKWNFPPihrCzHN8end1J1maoU30dteDtzSb5B4cMtoEfz7WzF2HtOHEGgKMQmqxzedw2aKWbJyNvyz6YmvTu9BJDAK_9qbUtPnlSdC_suHP3TIWFcY3L_9LW7FcKdQqYG-fceDGWvHWjNPonsNPbdv70U_SFZrNE6yW4MUvsyVHB4yCOrppYx2kKKMkSfMXcn0VY0DP1XWYU1wKh-xDg9yqsoInDXqV6NyShPNwo-jQ_IsBMbPQTAdz_DTwQ","e":"AQAB","use":"sig","kid":"943649050387808256_sig","qi":"DLjlRehZo3S2JsfF2ypXy0bMz0GAdCW0KNtdAtSt7ZG36V_4wiLphr1DmxG9Xw090IfDdch9HLXy3ofe1G-P1Ab3xGVaV6taUzqKpqCLmMpXdB-OfwILkr_q0iDyulr5boSWLruahZO0SfBJEFM2ZVzvJjElVDkB0LRS3-X0wgY","dp":"KT01P8svCLhq7VEZ4cefp6jIeWlxgNP0j1gSjsm0ZCIr0yXKhrAkznwqsazKxg7JTaXRfuAI6BXHV_WNTtp75xDXP0xCbXEjZfPjFXxeQj5lCpAErGMlbhsWx7WwwYRiwezhDUKI1PVzW-n7T2-dQ1qXSyIg8teZc8Vuojpp6Rs","alg":"RS256","dq":"swZL398EOYI8eqclbq-m6AUBDkAoJU03e852eb2UDt20arUa6MV98aMLzrFsAusdOH4k5jsfI3yeN2_R0HpyOwLd7gYb_eYUFksYE1lwCOXs9TXAs7W9K2mgG7JTOPuV7JHVVr-lbLN1o2LR8AGs3USUVumHrUZKlX70dHeQaPs","n":"5Hhw15l7kwYwVlJvHdaV-ZRD80wHrTbloW2n_LXWRfOPAbdHIy6UxOiaWtfbFgeLBDgAniQPl2KTfPoi25wa0OKG4usaYb2kdm6bVJlAMmok615qFEomL7ggxArnhpmj0DTQjSCopzr-8IlqLdNRYQMFUkDfJRnBCBPCs7xWZ1gM5HzmoGWPb2YeyYZE-89GZwaNmhs73qq1jEPJBGh61Co-SFe0x3O6-MEwGTxiX0y2VNqlWLE8A11AS2LYDCyC5k_1_mwm4D1xwO9CxwMZnnmCyvmhHxTAkzG4GVnc0qjYx1KXOwQy8Hk3Iw8Nk9pcUFYbqO7mZ-dS5F4LZ0blEQ"}', 300, E'http://192.168.20.19/U9/mvc/login/index', E'jwt', E'POST', E'1');
INSERT INTO mxk_apps_jwt_details (id, issuer, subject, audience, algorithmkey, algorithm, encryptionmethod, signature, signaturekey, expires, redirecturi, jwtname, tokentype, instid) VALUES (E'943649172014235648', E'2', E'username', NULL, E'GdzAMTMwMTIwMjQyMDQ2MTUzNTcdCw', E'NONE', E'A192GCM', E'RS256', E'{"p":"2EoFtNOBlsJ1C25af4tjf9Xd7FbXwaein6FJvSdoN9W9MTZKvrC5vXGWZXuDUEOZD0wOHRLT4MHyg_0hSOSpLWqBKJv2FtKsYf2dwoYQoXd8N-jKXUQlET63VOR01MSdLcViKqha26_rkwiVX7_vk7GHFkBByguFYPz_1y1fSw0","kty":"RSA","q":"_1I2eU8I1ZsjiktG3EALbPbU3AZYvK5HexQKPZSKk7qE1TPcVR6EjK0CEMhSiHgYNhlS6Kr26qz-CclscY_MIkWkANRl0xKR3qAy3JpFHORwd52zui6zP33c6DEp9hyA9_zE2ab4ewQxPe_5rSCdUETokMAdh3SmxGpNxQv2XrU","d":"GCsxiX_F3lGhQKJSYCmC2wQ_YRf0gjA2Wz_RifC7mmQShg5p-0DLDku8yQUozBGxID06plKXftLRHDQw6AwOXfKtqXLwuzUBDwXY4Zo-yBrcXPH4-csF-yYpG95EfESsfqlsnbUDSJ_Y0amUjXk-qjUuGvG0q9le5kimGU1LcTp3sIoGgWPPAJn2YvBud5sn27Nj3J8YNER-mbksjkhxDkD7AQw0y9yHIlhbSF9g0vSmjCE446bZM8Sqxyw51f9eihEfU335-FKj-WTxKhxd2irn-JDm_waB0sivkUe8TFf4MqkpYi0iTwrxkJ_MGfLpFBGHbCj9JcCd_O-SO7jVdQ","e":"AQAB","use":"sig","kid":"943649172014235648_sig","qi":"fAtqWhxlYfyrzqwtCmmlxw9K5uKdNhyJg83Q_HI1g7Qio3LWzW2uBmcR9fOu0TN6fWexePBDAqtkMGrDxiA-6q7q3jGNsGV21ZZkkWKb3lDlMutj6wa28bOAUjHP1XNbTDCuW0m4Ry0yE5-PYhBLYxElrWfxeAsSK7aqIeQMIbY","dp":"zt-eLaLPpD9CbDiU3sGX3cHVjiRSIawRY9WFDiMPD7ikSNnBDDtErOpkC5TjuHWvhG4eYbiMZ8GaEJygpXPwTLw95XWnH5VJxEAsEM7iQU5jxaYnSKXRPnlaKRyKkqesHwdYKaz1moLdM7lWBksy_3Uh3CqBwprabDYRDuMa7lE","alg":"RS256","dq":"W1B8-Q_iOfs9T8Wydy1UqMjywipm7DxshkFZlEKe-UzZGyNsJuk-QM3TkksC8Zn6Fsch1uLmYnIyfS-T4F2shYlgqYdNT5sxnmyvJCTsmPO-oZk-YVU4eHm8WzLSLhptqcO2Z52G-wA52EwOgPPML5wljTeYmAyJZHAcll-74o0","n":"17cxaw2Q-k7vcJ-BLjMy6V4w6LsjR2sl-YD_03PvIUaAW4REkQcY0VphPt3-ANYbzUjn-LjGSbJWYIhJ2db2Mc4l2YNrK1pwSA-vg5Laa3TxSgmRR7l_GF3LRMqtuuwBedtQoxUVePUlgXBiSM6cXWVnsxUs5gBbeNC2D0094FRu1aNRs8mnmw1ItxH1VqRhJUMs6cLHMn2TaFBI6nmKRzWu8Okb_NKBnnx84TfvfmioUxflKjy55pJwboM8BvlYAEBnlG_Na_izISnQtsRQgvJdWWQg6Wjx2tU4dHzqc6czWfAkVffCIG-j5wakjeMweL7LRpGNF5sr1EGYv2zWMQ"}', 300, E'http://192.168.20.19/U9/mvc/login/index', E'jwt', E'POST', E'1');
INSERT INTO mxk_apps_saml_v20_details (id, certissuer, certsubject, certexpiration, keystore, spacsurl, issuer, entityid, validityinterval, nameidformat, nameidconvert, nameidsuffix, audience, encrypted, binding, signature, digestmethod, metaurl, instid) VALUES (E'632279563832918016', E'duan', E'CN=duan, OU=emwit, O=yunwei, L=shenzhen, ST=guangdong, C=cn', E'Fri Aug 22 16:21:15 CST 2031', E'\\xfeedfeed000000020000000200000002001c68747470733a2f2f6a6972612e6d61786b65792e746f703a383434330000017c1627b15c0005582e35303900000364308203603082024ba003020102020452e4c989300d06092a864886f70d01010b05003064310b300906035504061302636e31123010060355040813096775616e67646f6e673111300f060355040713087368656e7a68656e310f300d060355040a130679756e776569310e300c060355040b1305656d776974310d300b060355040313046475616e301e170d3231303832343038323131355a170d3331303832323038323131355a3064310b300906035504061302636e31123010060355040813096775616e67646f6e673111300f060355040713087368656e7a68656e310f300d060355040a130679756e776569310e300c060355040b1305656d776974310d300b060355040313046475616e3082011e300d06092a864886f70d01010105000382010b00308201060281fe087686c67cc5ddecb988bad78ea9f42d7080f531c485d53a75e6d12d1fa240e16800432fb49d63680259897b6c00c471162154188d214cfb1b44f165c6b49e9fcc4ec37b54c764098443a18ee80dfb66c7a22b471b7621f27da33730f6555d6a5d8e3c222c27ed4b4325d492f742af56573a4da3f6b1e305de230b27d341ebf9fc0116117cccc6796cd9e6a067b0ad1727cc23dd6f86df131c12e8667743fc5e324c036afc30d7c689969544834b2c061a0734919bd6b516add389a6b63a941624c4138f5983a6ded2c71c42c8c6f43b6dd1609db36677eb41753cbd991624fe0c9958b460528f09bf302acef61c5747a80cbd299d0c5a03ac6e0036551b0203010001a321301f301d0603551d0e04160414b01c49337333572d59e0b271aafc021aeedf0b7f300d06092a864886f70d01010b05000381ff0002d52f1b49454fd647e34a1ae62475a527f8c4dac5c073dcc968eaef2e2fdfdf35ffc4a41583c23450a9c8f51246ec3971a54c71381dc34292ae40b8fa782949978664f6a0f7b432a598f2f26fca2586362cf4f743e96ca0a45e8ee1d9b79d58278c5d8250be5a4249f09d2862ec1854dabdb94d0cd2f7997499cd1e11f3c424c2c8367e6993b374a3bab55f0b72fca01c898ca7149445864d199ae626229250f85ff07ee6173b67d3a67f53b15b0861f1702bf6b0d62e0c06755cd5bf6d3e82086d66bc5791d7e589a8e03657692703c6d7c734b3e82d9dd31b785dadd66e0b1c45f56c6b2d4ff0485588989f8493c8d8260481d5fd4d2c5b23d81450cd00000001000a6d61786b65792e746f7000000172ead6fd5e00000500308204fc300e060a2b060104012a021101010500048204e82934c231aa1c5d9b03cc22e9455d7ac90295eca183ec3400a99b2c3ffb09e015bdcf7f60c6023b33351843e11b3f2c0465225e526f76f6a7e587095b5c2b741fb3ee7a08de7ef4c3468e8fb74db9b4d027c331347d34e457042959dc7eec6ba0831c45d13b0c74b4250e21f043d0500b70d360ee596f85e64babe0c54d87960423526035d7a1dfa751dc2d06eac31c645a0c637743a43468ddc7b134b602a64e08dc70e4b923014487be7c8abf56bdf6903da70a7620cb9e6fc50f0a435a3803171ae566b82207f3db794e13691cba809eb714f005e8c8feaab98bd32f75f2d90c8b2081040e000abada82473ed88de42b6d88d57421fe810c89a8fbcd8a22e9c3568bdd3aaa5fe310422cd28664b2cad7bd7078a977396c4ff7be643c07fe1fe40d39755720e098f883ca1de70e3727519268762a2698c781390b6b0b5e6aa09c6e97ac6156d74c7b7f8997cb7f4e7e00f623132ba6a261d14d71461a29d350ffe3bacd66209f50d3ac7e29415f34c7c91213899feb3ece4133c73d212ffac8b4149bbc8a7427154527b55f150dbd8365a52a0a63f13e6b117e35641eff1d9ed3b2cfa50ae29684d60ba578aab80a5f9204874859de215f96eaa57da5d68725a090af11992866aa07d5b1773de45e4dbfe499a62085af4c40f816f819b6afa91e010fa3512c391759de15d6f34a6e3d6e316dda2e0d10880037837ffbe0ecf9e810d5874e5ba31fdaddd8b7c35507366d7ae5f94c2356777503cfd0fc44a98abcd0fe6e03567b3742b6826c8eaee9d2864cda29540790d18d59c75651dbc94b10693231141b97603eeb1d06e4315c50e11b7b9bfcc94f5d5408ec336ad24b0a171b365359c470d958f17f897d467a907ffef631cabb0755d01d0be9f62b4469d0e2f770a5656f118ee669f8b7e4b7743e102eb76f6249a0b12f09307751a887101e93440b320a3b002712b9edc520665301da6f7de9bdb86cd76ee3c9793ca4a913b0eb1b5ce7de52327cdccd6fb0bbad380c530101a88e938cbe7204ca01e65993b6a39e267014ee7bc9f2fbb52ec93410512bba45297a9dce86c4812af3976594eb552f16e4334c48c42f3986abebb622ac603394239f3165e33a4c751a2992fb434a9c7f72b9b39466d14437bd9e35244eb48597c479dbce23ebf0cde42ced753c26bf7f2fcadf7d8b7b324226ae2598786cb914ac7da1152437e1ca03df86a4d2e1e92f24331ac9e8c73dad5597a0fafd8d28f455651a871cdb558218bd572a6423eae4e81a9d54a70ed1de11193baef1a80173fcf6223965a71f478182273fb7c71b43375854e30754b187326ebec21bc14cf96f1ccb2d1fbb2ca29da62de3b1ad584959ed2f69ffd87aff5ec22340e804dda0a0a26ca7314d1ceb79b815eda9e6b3707674eacc20045ff9ac411715f1c031e7deb3d20ec044b6d92ccf84f0052397189e8e6d1d3053afaf7418cc510b5ac675cceee155cbbfbcca426f8c9566e18f7800bc182258a93db1622d39599e8d0e299b0e7c168d5ce6cc4b16445cbe3590753571238b346940d66ac8ed6855f952b6696fc6fbc165951c62d38affa1f269acb395e2f952aea3d940422a970bea7d458d90965d2de8ce7b0223e9ed5fdfbf561b661e138f282384d40f75172d924ee6dc8a0cc89a7ee0fea867b1daa83386a1e22186bbd17b513ce10986c6d8fc7eb06915002a06a4dc494b63a85e069a7f300e78cf5235f1a4dc0b0f35e63b7e385a591ff432c070fbc91ed20e97e97294b09c63000000010005582e353039000003823082037e30820266a00302010202045e572d8b300d06092a864886f70d01010b05003081803120301e06092a864886f70d01090116117368696d696e677879403136332e636f6d310b300906035504061302636e310b300906035504080c027368310b300906035504070c027368310f300d060355040a0c066d61786b6579310f300d060355040b0c066d61786b65793113301106035504030c0a6d61786b65792e6f7267301e170d3230303232373032343733315a170d3430303232373032343733315a3081803120301e06092a864886f70d01090116117368696d696e677879403136332e636f6d310b300906035504061302636e310b300906035504080c027368310b300906035504070c027368310f300d060355040a0c066d61786b6579310f300d060355040b0c066d61786b65793113301106035504030c0a6d61786b65792e6f726730820122300d06092a864886f70d01010105000382010f003082010a0282010100b333dcf851f74ac4194fa1408d8a96f7db57df0950b9e8bf7adfdf8d99eac6674745ad9547195e4d3d5c51fe1f93ee68c1df551d8740877e4f58ee70c4a6e97c2671ef6280e00fb21b2b2111d8866a4b44a86893993ce80e973e3da0f538add1447ebf685f5ad1b9ea1b7bb452200a70223503c0f1fe5f31f92f532f6e63bacc38981aac56509dd7d022aab5354240702d90527c2cc11d5718b794b7f6a68f7844e9017785dcfe948cd5c3c915d01e4cd644da09a11d7d3fa2d091e90ab95c60d5310f3f45020b92e1496e373ca8327b080dd8e1a13bd29cfbd83063e10e3c487d80be4af9244bfbc20b34024deeed4e86877ab911f397d1933db371079a06070203010001300d06092a864886f70d01010b05000382010100186f61713baf5304cf90bf269018143469bc3dcc44dba8ce169065f3d3438f91974cebf86af8c05afa322efc10e44d582fcde6466b64b7de6ba67275a6a40f969a5ed04ee0a5a7d0a027512b2896fe033b093f3a10c5c318dbf5f79b5fcf228f4e570845ec0e81b3b01dcc5175136055cf2239441d09ce1ffe403905d9db75b1934cde5cba61028222ad9a00c1ea89e21940bf9f499a104f7faa1a9de3118fa9945998f25342661737e5070ccaeeca70b548e82b5172767fbe636c1fd1cc59bea469cada5c241549c2103f1100461dfea6b9c89497e2204a0c228deb18f5008a812ff2d30e009e3bdb4956f03fcdefe197c082ed1045691216c40a0cde8d372d55e6e83bf330e83eeea67251e4e635b52b201f72'::bytea, E'https://jira.maxkey.top:8443/plugins/servlet/samlconsumer', E'https://jira.maxkey.top:8443', E'https://jira.maxkey.top:8443', 300, E'persistent', E'original', NULL, E'https://jira.maxkey.top:8443', E'no', E'Redirect-Post', E'RSAwithSHA1', E'SHA1', E'', E'1');
INSERT INTO mxk_apps_saml_v20_details (id, certissuer, certsubject, certexpiration, keystore, spacsurl, issuer, entityid, validityinterval, nameidformat, nameidconvert, nameidsuffix, audience, encrypted, binding, signature, digestmethod, metaurl, instid) VALUES (E'638748653346881536', E'duan', E'CN=duan, OU=emwit, O=yunwei, L=shenzhen, ST=guangdong, C=cn', E'Fri Aug 22 16:21:15 CST 2031', E'\\xfeedfeed00000002000000020000000200033232320000017c15f78ebc0005582e35303900000364308203603082024ba003020102020452e4c989300d06092a864886f70d01010b05003064310b300906035504061302636e31123010060355040813096775616e67646f6e673111300f060355040713087368656e7a68656e310f300d060355040a130679756e776569310e300c060355040b1305656d776974310d300b060355040313046475616e301e170d3231303832343038323131355a170d3331303832323038323131355a3064310b300906035504061302636e31123010060355040813096775616e67646f6e673111300f060355040713087368656e7a68656e310f300d060355040a130679756e776569310e300c060355040b1305656d776974310d300b060355040313046475616e3082011e300d06092a864886f70d01010105000382010b00308201060281fe087686c67cc5ddecb988bad78ea9f42d7080f531c485d53a75e6d12d1fa240e16800432fb49d63680259897b6c00c471162154188d214cfb1b44f165c6b49e9fcc4ec37b54c764098443a18ee80dfb66c7a22b471b7621f27da33730f6555d6a5d8e3c222c27ed4b4325d492f742af56573a4da3f6b1e305de230b27d341ebf9fc0116117cccc6796cd9e6a067b0ad1727cc23dd6f86df131c12e8667743fc5e324c036afc30d7c689969544834b2c061a0734919bd6b516add389a6b63a941624c4138f5983a6ded2c71c42c8c6f43b6dd1609db36677eb41753cbd991624fe0c9958b460528f09bf302acef61c5747a80cbd299d0c5a03ac6e0036551b0203010001a321301f301d0603551d0e04160414b01c49337333572d59e0b271aafc021aeedf0b7f300d06092a864886f70d01010b05000381ff0002d52f1b49454fd647e34a1ae62475a527f8c4dac5c073dcc968eaef2e2fdfdf35ffc4a41583c23450a9c8f51246ec3971a54c71381dc34292ae40b8fa782949978664f6a0f7b432a598f2f26fca2586362cf4f743e96ca0a45e8ee1d9b79d58278c5d8250be5a4249f09d2862ec1854dabdb94d0cd2f7997499cd1e11f3c424c2c8367e6993b374a3bab55f0b72fca01c898ca7149445864d199ae626229250f85ff07ee6173b67d3a67f53b15b0861f1702bf6b0d62e0c06755cd5bf6d3e82086d66bc5791d7e589a8e03657692703c6d7c734b3e82d9dd31b785dadd66e0b1c45f56c6b2d4ff0485588989f8493c8d8260481d5fd4d2c5b23d81450cd00000001000a6d61786b65792e746f7000000172ead6fd5e00000500308204fc300e060a2b060104012a021101010500048204e82934c231aa1c5d9b03cc22e9455d7ac90295eca183ec3400a99b2c3ffb09e015bdcf7f60c6023b33351843e11b3f2c0465225e526f76f6a7e587095b5c2b741fb3ee7a08de7ef4c3468e8fb74db9b4d027c331347d34e457042959dc7eec6ba0831c45d13b0c74b4250e21f043d0500b70d360ee596f85e64babe0c54d87960423526035d7a1dfa751dc2d06eac31c645a0c637743a43468ddc7b134b602a64e08dc70e4b923014487be7c8abf56bdf6903da70a7620cb9e6fc50f0a435a3803171ae566b82207f3db794e13691cba809eb714f005e8c8feaab98bd32f75f2d90c8b2081040e000abada82473ed88de42b6d88d57421fe810c89a8fbcd8a22e9c3568bdd3aaa5fe310422cd28664b2cad7bd7078a977396c4ff7be643c07fe1fe40d39755720e098f883ca1de70e3727519268762a2698c781390b6b0b5e6aa09c6e97ac6156d74c7b7f8997cb7f4e7e00f623132ba6a261d14d71461a29d350ffe3bacd66209f50d3ac7e29415f34c7c91213899feb3ece4133c73d212ffac8b4149bbc8a7427154527b55f150dbd8365a52a0a63f13e6b117e35641eff1d9ed3b2cfa50ae29684d60ba578aab80a5f9204874859de215f96eaa57da5d68725a090af11992866aa07d5b1773de45e4dbfe499a62085af4c40f816f819b6afa91e010fa3512c391759de15d6f34a6e3d6e316dda2e0d10880037837ffbe0ecf9e810d5874e5ba31fdaddd8b7c35507366d7ae5f94c2356777503cfd0fc44a98abcd0fe6e03567b3742b6826c8eaee9d2864cda29540790d18d59c75651dbc94b10693231141b97603eeb1d06e4315c50e11b7b9bfcc94f5d5408ec336ad24b0a171b365359c470d958f17f897d467a907ffef631cabb0755d01d0be9f62b4469d0e2f770a5656f118ee669f8b7e4b7743e102eb76f6249a0b12f09307751a887101e93440b320a3b002712b9edc520665301da6f7de9bdb86cd76ee3c9793ca4a913b0eb1b5ce7de52327cdccd6fb0bbad380c530101a88e938cbe7204ca01e65993b6a39e267014ee7bc9f2fbb52ec93410512bba45297a9dce86c4812af3976594eb552f16e4334c48c42f3986abebb622ac603394239f3165e33a4c751a2992fb434a9c7f72b9b39466d14437bd9e35244eb48597c479dbce23ebf0cde42ced753c26bf7f2fcadf7d8b7b324226ae2598786cb914ac7da1152437e1ca03df86a4d2e1e92f24331ac9e8c73dad5597a0fafd8d28f455651a871cdb558218bd572a6423eae4e81a9d54a70ed1de11193baef1a80173fcf6223965a71f478182273fb7c71b43375854e30754b187326ebec21bc14cf96f1ccb2d1fbb2ca29da62de3b1ad584959ed2f69ffd87aff5ec22340e804dda0a0a26ca7314d1ceb79b815eda9e6b3707674eacc20045ff9ac411715f1c031e7deb3d20ec044b6d92ccf84f0052397189e8e6d1d3053afaf7418cc510b5ac675cceee155cbbfbcca426f8c9566e18f7800bc182258a93db1622d39599e8d0e299b0e7c168d5ce6cc4b16445cbe3590753571238b346940d66ac8ed6855f952b6696fc6fbc165951c62d38affa1f269acb395e2f952aea3d940422a970bea7d458d90965d2de8ce7b0223e9ed5fdfbf561b661e138f282384d40f75172d924ee6dc8a0cc89a7ee0fea867b1daa83386a1e22186bbd17b513ce10986c6d8fc7eb06915002a06a4dc494b63a85e069a7f300e78cf5235f1a4dc0b0f35e63b7e385a591ff432c070fbc91ed20e97e97294b09c63000000010005582e353039000003823082037e30820266a00302010202045e572d8b300d06092a864886f70d01010b05003081803120301e06092a864886f70d01090116117368696d696e677879403136332e636f6d310b300906035504061302636e310b300906035504080c027368310b300906035504070c027368310f300d060355040a0c066d61786b6579310f300d060355040b0c066d61786b65793113301106035504030c0a6d61786b65792e6f7267301e170d3230303232373032343733315a170d3430303232373032343733315a3081803120301e06092a864886f70d01090116117368696d696e677879403136332e636f6d310b300906035504061302636e310b300906035504080c027368310b300906035504070c027368310f300d060355040a0c066d61786b6579310f300d060355040b0c066d61786b65793113301106035504030c0a6d61786b65792e6f726730820122300d06092a864886f70d01010105000382010f003082010a0282010100b333dcf851f74ac4194fa1408d8a96f7db57df0950b9e8bf7adfdf8d99eac6674745ad9547195e4d3d5c51fe1f93ee68c1df551d8740877e4f58ee70c4a6e97c2671ef6280e00fb21b2b2111d8866a4b44a86893993ce80e973e3da0f538add1447ebf685f5ad1b9ea1b7bb452200a70223503c0f1fe5f31f92f532f6e63bacc38981aac56509dd7d022aab5354240702d90527c2cc11d5718b794b7f6a68f7844e9017785dcfe948cd5c3c915d01e4cd644da09a11d7d3fa2d091e90ab95c60d5310f3f45020b92e1496e373ca8327b080dd8e1a13bd29cfbd83063e10e3c487d80be4af9244bfbc20b34024deeed4e86877ab911f397d1933db371079a06070203010001300d06092a864886f70d01010b05000382010100186f61713baf5304cf90bf269018143469bc3dcc44dba8ce169065f3d3438f91974cebf86af8c05afa322efc10e44d582fcde6466b64b7de6ba67275a6a40f969a5ed04ee0a5a7d0a027512b2896fe033b093f3a10c5c318dbf5f79b5fcf228f4e570845ec0e81b3b01dcc5175136055cf2239441d09ce1ffe403905d9db75b1934cde5cba61028222ad9a00c1ea89e21940bf9f499a104f7faa1a9de3118fa9945998f25342661737e5070ccaeeca70b548e82b5172767fbe636c1fd1cc59bea469cada5c241549c2103f1100461dfea6b9c89497e2204a0c228deb18f5008a812ff2d30e009e3bdb4956f03fcdefe197c082ed1045691216c40a0cde8d372dacd38046ca27f0d589a9a85b29fb530f8eae7af8'::bytea, E'2222', E'22', E'222', 15, E'persistent', E'original', NULL, E'22', E'no', E'Redirect-Post', E'RSAwithSHA1', E'SHA1', E'', E'1');
INSERT INTO mxk_apps_saml_v20_details (id, certissuer, certsubject, certexpiration, keystore, spacsurl, issuer, entityid, validityinterval, nameidformat, nameidconvert, nameidsuffix, audience, encrypted, binding, signature, digestmethod, metaurl, instid) VALUES (E'822180682301177856', E'apollo', E'CN=apollo, OU=R&D, O=RM5 Software Oy, L=Helsinki, ST=Uusimaa, C=FI', E'Fri Dec 30 19:28:01 CST 2022', E'\\xfeedfeed0000000200000002000000020018636f6d3a7664656e6f74617269733a737072696e673a737000000175e135886b0005582e35303900000356308203523082023aa003020102020450e2c841300d06092a864886f70d0101050500306b310b30090603550406130246493110300e06035504081307557573696d61613111300f0603550407130848656c73696e6b6931183016060355040a130f524d3520536f667477617265204f79310c300a060355040b0c03522644310f300d0603550403130661706f6c6c6f301e170d3133303130313131323830315a170d3232313233303131323830315a306b310b30090603550406130246493110300e06035504081307557573696d61613111300f0603550407130848656c73696e6b6931183016060355040a130f524d3520536f667477617265204f79310c300a060355040b0c03522644310f300d0603550403130661706f6c6c6f30820122300d06092a864886f70d01010105000382010f003082010a028201010097a8fd30a8bd808b585a7938f46a5c2c2da7e1ac3b54b74d04e7173b91d0fb3c8491036ef4666a58301e16db8524d9092ec1a069e9d23fc91754bcf7ce4f8e5866ba88c4c7b6e39d4f0105ad10a585e59d77174278fe507bd53b6bcf21fde119ea4875c57ef44df0463faf3b84ceba59ac776d36cf4b4722ea7114d730c3b8cfb420841bb18772b982eecaab1a47c7a368f3758d663e01de0bd62d15afd399db5e1fc5f5831e4029535f588134084b4315a1c1730a078bb588f43f29269a977476ea938d5149aed6a56d535aae428cd24cf0fc1efb03a861b5f6fdbefcddee7f975162dbc43dfc17377c0863efd1f77bc103a9679799d372d64846cca0d06bf90203010001300d06092a864886f70d0101050500038201010054300006148eca355708c3736932a4afd145c07c6cc0145081b484b18bf3622f9caa2e1a2c46a807142f040a22f4eceae1a69606d21ba1a7e5139bda6941ced5ea438f7346f8b9a96351b6d8abe9ecaac1114638ce80f2bc63dc98718b655bfcc267ed7cde5471cbcc0d6c57987097fd8f2e768bda1f56c86f50c016f0b6690c12a52dfdd822c4a6f546f6f2fed06e46881680f38d352002896f99e68f147403aa34c650a330ff8b580e8c15e81741793a4b2340def1a1064b8fdc5779fc42150ebd14f7050de1166c7c12a01cb984b3cd00b6845286b9ccf0f0962c704631504dce575da4698088f2ff682c2fcf98e50461c979cbaa03baec194b616fc6b87100000001000a6d61786b65792e746f7000000172ead6fd5e00000500308204fc300e060a2b060104012a021101010500048204e82934c231aa1c5d9b03cc22e9455d7ac90295eca183ec3400a99b2c3ffb09e015bdcf7f60c6023b33351843e11b3f2c0465225e526f76f6a7e587095b5c2b741fb3ee7a08de7ef4c3468e8fb74db9b4d027c331347d34e457042959dc7eec6ba0831c45d13b0c74b4250e21f043d0500b70d360ee596f85e64babe0c54d87960423526035d7a1dfa751dc2d06eac31c645a0c637743a43468ddc7b134b602a64e08dc70e4b923014487be7c8abf56bdf6903da70a7620cb9e6fc50f0a435a3803171ae566b82207f3db794e13691cba809eb714f005e8c8feaab98bd32f75f2d90c8b2081040e000abada82473ed88de42b6d88d57421fe810c89a8fbcd8a22e9c3568bdd3aaa5fe310422cd28664b2cad7bd7078a977396c4ff7be643c07fe1fe40d39755720e098f883ca1de70e3727519268762a2698c781390b6b0b5e6aa09c6e97ac6156d74c7b7f8997cb7f4e7e00f623132ba6a261d14d71461a29d350ffe3bacd66209f50d3ac7e29415f34c7c91213899feb3ece4133c73d212ffac8b4149bbc8a7427154527b55f150dbd8365a52a0a63f13e6b117e35641eff1d9ed3b2cfa50ae29684d60ba578aab80a5f9204874859de215f96eaa57da5d68725a090af11992866aa07d5b1773de45e4dbfe499a62085af4c40f816f819b6afa91e010fa3512c391759de15d6f34a6e3d6e316dda2e0d10880037837ffbe0ecf9e810d5874e5ba31fdaddd8b7c35507366d7ae5f94c2356777503cfd0fc44a98abcd0fe6e03567b3742b6826c8eaee9d2864cda29540790d18d59c75651dbc94b10693231141b97603eeb1d06e4315c50e11b7b9bfcc94f5d5408ec336ad24b0a171b365359c470d958f17f897d467a907ffef631cabb0755d01d0be9f62b4469d0e2f770a5656f118ee669f8b7e4b7743e102eb76f6249a0b12f09307751a887101e93440b320a3b002712b9edc520665301da6f7de9bdb86cd76ee3c9793ca4a913b0eb1b5ce7de52327cdccd6fb0bbad380c530101a88e938cbe7204ca01e65993b6a39e267014ee7bc9f2fbb52ec93410512bba45297a9dce86c4812af3976594eb552f16e4334c48c42f3986abebb622ac603394239f3165e33a4c751a2992fb434a9c7f72b9b39466d14437bd9e35244eb48597c479dbce23ebf0cde42ced753c26bf7f2fcadf7d8b7b324226ae2598786cb914ac7da1152437e1ca03df86a4d2e1e92f24331ac9e8c73dad5597a0fafd8d28f455651a871cdb558218bd572a6423eae4e81a9d54a70ed1de11193baef1a80173fcf6223965a71f478182273fb7c71b43375854e30754b187326ebec21bc14cf96f1ccb2d1fbb2ca29da62de3b1ad584959ed2f69ffd87aff5ec22340e804dda0a0a26ca7314d1ceb79b815eda9e6b3707674eacc20045ff9ac411715f1c031e7deb3d20ec044b6d92ccf84f0052397189e8e6d1d3053afaf7418cc510b5ac675cceee155cbbfbcca426f8c9566e18f7800bc182258a93db1622d39599e8d0e299b0e7c168d5ce6cc4b16445cbe3590753571238b346940d66ac8ed6855f952b6696fc6fbc165951c62d38affa1f269acb395e2f952aea3d940422a970bea7d458d90965d2de8ce7b0223e9ed5fdfbf561b661e138f282384d40f75172d924ee6dc8a0cc89a7ee0fea867b1daa83386a1e22186bbd17b513ce10986c6d8fc7eb06915002a06a4dc494b63a85e069a7f300e78cf5235f1a4dc0b0f35e63b7e385a591ff432c070fbc91ed20e97e97294b09c63000000010005582e353039000003823082037e30820266a00302010202045e572d8b300d06092a864886f70d01010b05003081803120301e06092a864886f70d01090116117368696d696e677879403136332e636f6d310b300906035504061302636e310b300906035504080c027368310b300906035504070c027368310f300d060355040a0c066d61786b6579310f300d060355040b0c066d61786b65793113301106035504030c0a6d61786b65792e6f7267301e170d3230303232373032343733315a170d3430303232373032343733315a3081803120301e06092a864886f70d01090116117368696d696e677879403136332e636f6d310b300906035504061302636e310b300906035504080c027368310b300906035504070c027368310f300d060355040a0c066d61786b6579310f300d060355040b0c066d61786b65793113301106035504030c0a6d61786b65792e6f726730820122300d06092a864886f70d01010105000382010f003082010a0282010100b333dcf851f74ac4194fa1408d8a96f7db57df0950b9e8bf7adfdf8d99eac6674745ad9547195e4d3d5c51fe1f93ee68c1df551d8740877e4f58ee70c4a6e97c2671ef6280e00fb21b2b2111d8866a4b44a86893993ce80e973e3da0f538add1447ebf685f5ad1b9ea1b7bb452200a70223503c0f1fe5f31f92f532f6e63bacc38981aac56509dd7d022aab5354240702d90527c2cc11d5718b794b7f6a68f7844e9017785dcfe948cd5c3c915d01e4cd644da09a11d7d3fa2d091e90ab95c60d5310f3f45020b92e1496e373ca8327b080dd8e1a13bd29cfbd83063e10e3c487d80be4af9244bfbc20b34024deeed4e86877ab911f397d1933db371079a06070203010001300d06092a864886f70d01010b05000382010100186f61713baf5304cf90bf269018143469bc3dcc44dba8ce169065f3d3438f91974cebf86af8c05afa322efc10e44d582fcde6466b64b7de6ba67275a6a40f969a5ed04ee0a5a7d0a027512b2896fe033b093f3a10c5c318dbf5f79b5fcf228f4e570845ec0e81b3b01dcc5175136055cf2239441d09ce1ffe403905d9db75b1934cde5cba61028222ad9a00c1ea89e21940bf9f499a104f7faa1a9de3118fa9945998f25342661737e5070ccaeeca70b548e82b5172767fbe636c1fd1cc59bea469cada5c241549c2103f1100461dfea6b9c89497e2204a0c228deb18f5008a812ff2d30e009e3bdb4956f03fcdefe197c082ed1045691216c40a0cde8d372d47d51cb2b8ead7cd767d77e9d3365090e5417ac5'::bytea, E'http://sso.maxkey.top:8080/saml/SSO', E'com:vdenotaris:spring:sp', E'com:vdenotaris:spring:sp', 15, E'persistent', E'original', NULL, E'com:vdenotaris:spring:sp', E'no', E'Redirect-Post', E'RSAwithSHA1', E'SHA1', E'', E'1');
INSERT INTO mxk_apps_saml_v20_details (id, certissuer, certsubject, certexpiration, keystore, spacsurl, issuer, entityid, validityinterval, nameidformat, nameidconvert, nameidsuffix, audience, encrypted, binding, signature, digestmethod, metaurl, instid) VALUES (E'823620386997403648', E'Alibaba', E'CN=Alibaba, OU=Apsara, O=Alibaba Inc, L=Hangzhou, C=CN', E'Sat Mar 13 01:59:19 CST 2027', E'\\xfeedfeed000000020000000200000002003368747470733a2f2f7369676e696e2e616c6979756e2e636f6d2f313732393938323638333332333730332f73616d6c2f73736f0000017605893a180005582e353039000003553082035130820239a003020102020422fdaff4300d06092a864886f70d01010b05003059310b300906035504061302434e3111300f0603550407130848616e677a686f7531143012060355040a130b416c696261626120496e63310f300d060355040b13064170736172613110300e06035504031307416c6962616261301e170d3137303331343137353931395a170d3237303331323137353931395a3059310b300906035504061302434e3111300f0603550407130848616e677a686f7531143012060355040a130b416c696261626120496e63310f300d060355040b13064170736172613110300e06035504031307416c696261626130820122300d06092a864886f70d01010105000382010f003082010a0282010100aa2b61d1b5fe2c9aff69090b4f7a7144d70ea5bf1b078afd09fe49efa42d4153888059c4bc2f100494a6f8f506ca1ee53173010625f9b4fb3669a92f892378e619ce1a1d8002c8bd96c6d28dc7fe442b542ce6e8028a99fb83ec923aa5f173f46fd92ee6bb0e8b4eb1954d3eefa34f44503919337e2c4eea6e53bb735f492d6218a6c70b241bda3b6ef66e40a41feba80df25fc3533c94979f7fd30035fb1e40e41de9bda001080e9dab89a2f26b497d35dca969b4ebe16054d3e02a8e7db8feb2d3cad02578ca0f02c87f4a30ba8891acf2d1e49282d6f43a3d2cf4706bfcb4652db3976bff4cc6147cb88776ae7d08970928b8e16501dc57a34107e012205d0203010001a321301f301d0603551d0e04160414a158deb59d9b16cfd3189d2ad59029099d2745b4300d06092a864886f70d01010b0500038201010030c025f82de8c88ea464d9af5f4e526f4aba50033cc2a8c529b3e14928b2b2b8d56708c48e26673929e85fcbced3b7ec669715981c87cc65d6b81c71282be20a94024bd87239317a6ef0285f07b7ee1d36521bf7b4a234ec54645c903b1de0741c4b873c2071c5655625f82d91e5044e7195d3a0ab52518e37b0eede1dfb114cdf4ea98a865b2a29e2bcbaac3780b62a069e942eb3f53db368d806873186998452f575252d358bde919a69ade81928c203aad126e8fc29c36963f208d30b8d0f4341ae5c4793b1f139761c38db173d464c948351a8d3893d67f50cc535f4295322459f431761568d6a75000409dd3bd9d80a3f5ce86693819645e854a07afb1f00000001000a6d61786b65792e746f7000000172ead6fd5e00000500308204fc300e060a2b060104012a021101010500048204e82934c231aa1c5d9b03cc22e9455d7ac90295eca183ec3400a99b2c3ffb09e015bdcf7f60c6023b33351843e11b3f2c0465225e526f76f6a7e587095b5c2b741fb3ee7a08de7ef4c3468e8fb74db9b4d027c331347d34e457042959dc7eec6ba0831c45d13b0c74b4250e21f043d0500b70d360ee596f85e64babe0c54d87960423526035d7a1dfa751dc2d06eac31c645a0c637743a43468ddc7b134b602a64e08dc70e4b923014487be7c8abf56bdf6903da70a7620cb9e6fc50f0a435a3803171ae566b82207f3db794e13691cba809eb714f005e8c8feaab98bd32f75f2d90c8b2081040e000abada82473ed88de42b6d88d57421fe810c89a8fbcd8a22e9c3568bdd3aaa5fe310422cd28664b2cad7bd7078a977396c4ff7be643c07fe1fe40d39755720e098f883ca1de70e3727519268762a2698c781390b6b0b5e6aa09c6e97ac6156d74c7b7f8997cb7f4e7e00f623132ba6a261d14d71461a29d350ffe3bacd66209f50d3ac7e29415f34c7c91213899feb3ece4133c73d212ffac8b4149bbc8a7427154527b55f150dbd8365a52a0a63f13e6b117e35641eff1d9ed3b2cfa50ae29684d60ba578aab80a5f9204874859de215f96eaa57da5d68725a090af11992866aa07d5b1773de45e4dbfe499a62085af4c40f816f819b6afa91e010fa3512c391759de15d6f34a6e3d6e316dda2e0d10880037837ffbe0ecf9e810d5874e5ba31fdaddd8b7c35507366d7ae5f94c2356777503cfd0fc44a98abcd0fe6e03567b3742b6826c8eaee9d2864cda29540790d18d59c75651dbc94b10693231141b97603eeb1d06e4315c50e11b7b9bfcc94f5d5408ec336ad24b0a171b365359c470d958f17f897d467a907ffef631cabb0755d01d0be9f62b4469d0e2f770a5656f118ee669f8b7e4b7743e102eb76f6249a0b12f09307751a887101e93440b320a3b002712b9edc520665301da6f7de9bdb86cd76ee3c9793ca4a913b0eb1b5ce7de52327cdccd6fb0bbad380c530101a88e938cbe7204ca01e65993b6a39e267014ee7bc9f2fbb52ec93410512bba45297a9dce86c4812af3976594eb552f16e4334c48c42f3986abebb622ac603394239f3165e33a4c751a2992fb434a9c7f72b9b39466d14437bd9e35244eb48597c479dbce23ebf0cde42ced753c26bf7f2fcadf7d8b7b324226ae2598786cb914ac7da1152437e1ca03df86a4d2e1e92f24331ac9e8c73dad5597a0fafd8d28f455651a871cdb558218bd572a6423eae4e81a9d54a70ed1de11193baef1a80173fcf6223965a71f478182273fb7c71b43375854e30754b187326ebec21bc14cf96f1ccb2d1fbb2ca29da62de3b1ad584959ed2f69ffd87aff5ec22340e804dda0a0a26ca7314d1ceb79b815eda9e6b3707674eacc20045ff9ac411715f1c031e7deb3d20ec044b6d92ccf84f0052397189e8e6d1d3053afaf7418cc510b5ac675cceee155cbbfbcca426f8c9566e18f7800bc182258a93db1622d39599e8d0e299b0e7c168d5ce6cc4b16445cbe3590753571238b346940d66ac8ed6855f952b6696fc6fbc165951c62d38affa1f269acb395e2f952aea3d940422a970bea7d458d90965d2de8ce7b0223e9ed5fdfbf561b661e138f282384d40f75172d924ee6dc8a0cc89a7ee0fea867b1daa83386a1e22186bbd17b513ce10986c6d8fc7eb06915002a06a4dc494b63a85e069a7f300e78cf5235f1a4dc0b0f35e63b7e385a591ff432c070fbc91ed20e97e97294b09c63000000010005582e353039000003823082037e30820266a00302010202045e572d8b300d06092a864886f70d01010b05003081803120301e06092a864886f70d01090116117368696d696e677879403136332e636f6d310b300906035504061302636e310b300906035504080c027368310b300906035504070c027368310f300d060355040a0c066d61786b6579310f300d060355040b0c066d61786b65793113301106035504030c0a6d61786b65792e6f7267301e170d3230303232373032343733315a170d3430303232373032343733315a3081803120301e06092a864886f70d01090116117368696d696e677879403136332e636f6d310b300906035504061302636e310b300906035504080c027368310b300906035504070c027368310f300d060355040a0c066d61786b6579310f300d060355040b0c066d61786b65793113301106035504030c0a6d61786b65792e6f726730820122300d06092a864886f70d01010105000382010f003082010a0282010100b333dcf851f74ac4194fa1408d8a96f7db57df0950b9e8bf7adfdf8d99eac6674745ad9547195e4d3d5c51fe1f93ee68c1df551d8740877e4f58ee70c4a6e97c2671ef6280e00fb21b2b2111d8866a4b44a86893993ce80e973e3da0f538add1447ebf685f5ad1b9ea1b7bb452200a70223503c0f1fe5f31f92f532f6e63bacc38981aac56509dd7d022aab5354240702d90527c2cc11d5718b794b7f6a68f7844e9017785dcfe948cd5c3c915d01e4cd644da09a11d7d3fa2d091e90ab95c60d5310f3f45020b92e1496e373ca8327b080dd8e1a13bd29cfbd83063e10e3c487d80be4af9244bfbc20b34024deeed4e86877ab911f397d1933db371079a06070203010001300d06092a864886f70d01010b05000382010100186f61713baf5304cf90bf269018143469bc3dcc44dba8ce169065f3d3438f91974cebf86af8c05afa322efc10e44d582fcde6466b64b7de6ba67275a6a40f969a5ed04ee0a5a7d0a027512b2896fe033b093f3a10c5c318dbf5f79b5fcf228f4e570845ec0e81b3b01dcc5175136055cf2239441d09ce1ffe403905d9db75b1934cde5cba61028222ad9a00c1ea89e21940bf9f499a104f7faa1a9de3118fa9945998f25342661737e5070ccaeeca70b548e82b5172767fbe636c1fd1cc59bea469cada5c241549c2103f1100461dfea6b9c89497e2204a0c228deb18f5008a812ff2d30e009e3bdb4956f03fcdefe197c082ed1045691216c40a0cde8d372d62d4ed162a893bf7eab230d50fdc856e9835be5a'::bytea, E'https://signin.aliyun.com/saml/SSO', E'https://signin.aliyun.com/1729982683323703/saml/SSO', E'https://signin.aliyun.com/1729982683323703/saml/SSO', 15, E'persistent', E'original', NULL, E'https://signin.aliyun.com/1729982683323703/saml/SSO', E'no', E'Redirect-Post', E'RSAwithSHA1', E'SHA1', E'', E'1');
INSERT INTO mxk_apps_saml_v20_details (id, certissuer, certsubject, certexpiration, keystore, spacsurl, issuer, entityid, validityinterval, nameidformat, nameidconvert, nameidsuffix, audience, encrypted, binding, signature, digestmethod, metaurl, instid) VALUES (E'823720999999504384', E'VeriSign Class 3 International Server CA - G3', E'CN=proxy.salesforce.com, OU=Applications, O="Salesforce.com, Inc.", L=San Francisco, ST=California, C=US', E'17 Oct 2017 23:59:59 GMT', E'\\xfeedfeed000000020000000200000002002068747470733a2f2f73736f2e636f6e6e7365632e636f6d2f7365632f73616d6c000001434446add00005582e353039000005643082056030820448a00302010202104382b137b13768018fd6ba70426ea067300d06092a864886f70d01010505003081bc310b300906035504061302555331173015060355040a130e566572695369676e2c20496e632e311f301d060355040b1316566572695369676e205472757374204e6574776f726b313b3039060355040b13325465726d73206f66207573652061742068747470733a2f2f7777772e766572697369676e2e636f6d2f727061202863293130313630340603550403132d566572695369676e20436c617373203320496e7465726e6174696f6e616c20536572766572204341202d204733301e170d3133313031383030303030305a170d3137313031373233353935395a30818f310b3009060355040613025553311330110603550408130a43616c69666f726e6961311630140603550407140d53616e204672616e636973636f311d301b060355040a141453616c6573666f7263652e636f6d2c20496e632e31153013060355040b140c4170706c69636174696f6e73311d301b0603550403141470726f78792e73616c6573666f7263652e636f6d30820122300d06092a864886f70d01010105000382010f003082010a0282010100b26d4bff2d2663d9fc228ecff749ecc5eb833d0c3d02b1100760add3857518ec6af4d8f91be24447becf08eb29df59b024b71a5b55d860450fe6315f3ba9b50afe6540c2f15c31fb8f56435dc3e799e6a14255701d671e54d7048089403a3cedc678008562b9256451f4111bb05e31f29332783219d00e22c9d2170a7538d991a9a21aad64dfaf6c3448d14d3e2916f6b4237a1005fde87a21be07ddb24413f900c114b8985268c442ac8894219f29aa7a85602cc49bdd44d2f09f51d519908be922b02dfd340cd5c108ccd57ebbedc750b7415a17a1a567deef087feba4d0099c0570696891350df6011d97dfdae9f035694a4f5eca7346a75248ffa988bf710203010001a382018730820183301f0603551d1104183016821470726f78792e73616c6573666f7263652e636f6d30090603551d1304023000300e0603551d0f0101ff0404030205a030280603551d250421301f06082b0601050507030106082b0601050507030206096086480186f842040130430603551d20043c303a3038060a6086480186f845010736302a302806082b06010505070201161c68747470733a2f2f7777772e766572697369676e2e636f6d2f637073301f0603551d23041830168014d79b7cd822a015f7ddad5fce299b58c3bc4600b530410603551d1f043a30383036a034a0328630687474703a2f2f535652496e746c2d47332d63726c2e766572697369676e2e636f6d2f535652496e746c47332e63726c307206082b0601050507010104663064302406082b060105050730018618687474703a2f2f6f6373702e766572697369676e2e636f6d303c06082b060105050730028630687474703a2f2f535652496e746c2d47332d6169612e766572697369676e2e636f6d2f535652496e746c47332e636572300d06092a864886f70d010105050003820101000432c2f81c0779b985b78f4490157e0ea65ee9d15a38a3b1ca0470ad578663ce4485c2f451f7ee738a362a9617b8a2ed522f8580580b1328c4e92b3d022f54bd369b7421c2a6216791b2324a2b39c56bcb311e1804be6dced756bdb957e0be69f09f4544a6e4e61af5ef214480679ab40950e0cdb1acae35a765796580eea4af03e89c483a31d15aac0f3b6c090b0ab2d9d07a967945657f69ed7ef47b923af4b6b50cfc40713dd70fc5e30aef4109aa4bbb18c10f3b191ec53af63b4c83ff69593348a5f8052e39ba190e5d12c9f8d4d0ded820a34a66ae6172850ffec0a971178c363d1d016795626003ad5ecb94e56f9dd80729c2eb532752ffda1b4077a700000001000b636f6e6e7365632e636f6d0000013e89d40d9400000500308204fc300e060a2b060104012a021101010500048204e8cb1daf614de9041cbaa12dff35b3b79ebf058148666b3ceb9e93ad6e4809840ccd25d08a7b840c34ba239262baa8f97af5c40e3b9357bfc20d17cb8aa332ad3f309aec51432336a2887750405c0603aa3039434a2ef52a86997041ca61a7fbe1c4482fedf943048164425cfa144f20401e8245b97aee3df3006825ec623a7dc8c5c3cb4ea90ee0edabbc0513522798194387c12bc69a112a6b73abe977bf78eba02eee47d509b16b5b17a17797b36e5f2b85d903000b95739786c23da9607764b640d1f1da87489cfc7465b7146060fd03608fe212b18728352731075abdd9344c521568795ffa323379b0d1bf9921ac15cb4de41c2ce926fd8143810119da7ad26286155f02a350a1fbb14235cfb4cd0f149525a40ff620fdb916d0507d94b3c595639c9ad77f13719f8b48627e0fc40ebf37134df7ea79a59c92d08191609e4f95908e063d9c59bb81602fab72efd1eb18bc3a9b50837e83cb9e34566ffca3b780168db47fb44188375ebbfa9d2fcf4bfe6c62fb8e8b0272c061538229992415af8d54030b8b433f27a45623f9af69d1c4a4c11c671b9477cd3c65960a6c5402da0119aef1ba4dafa59b7b000aa1636c04962d8ba7138394c9121c005e3a56c2a6f811231a3c5fecbed382dc95b94f2b6c115e7d2eb6bc6b113153ab0ff84f270f3d4636117dd5beb36532bc43a9e27283caccd874f3b269b4f70a64d809e8a0474a4ff67e5a1748ae519d65bfa6cf347bc9eda574fa6dc075b78fd3ab0860a50746c259b071adb694a174a71d197c6b28f8e97df214923e894ab652efed0b8b0fc56a82b734e696aa0a5c376fcfb780ac3d52f95dcceb6c107a53d08da875a4e87edac58dbf803ea545f32e4f0098ed06d8e190b84548f987d7aa715a6c4e742a78d2edfa1e7492c5363a3f1e947fe517e24c1f55ba931138fce58c2367ecd1aa863bd62edd2d1052b0a73e0c93843252e3046acb172217acffabdf88c0965060d7c751fc7a0756b1373155d7bb7f13248905f05274448bac5f14346ba1f119e2cef62c080419d1dd6ff455fcf07305b799682670386b979031dca29834b9aa97d15a3889173559168bf5d431de97a6f0c8e121b045df0355f04ff30b342fa01730fddca136248bf95a89684e3a20c85f79ad0de75d4d7f671c85fb5590c3609643730dd6dbebd2f93843979c13d56cba57f0c720f89338be583f751368753d0b5224884ed341977a9689d8af65ac9b7b98ced51a3132e369efe23a3b60ca5a2d00b2297a1e27d4ec365da660cb09beb5170f836141e0f32c28154cba1215ebc671627018c3f8b0da2289f7d445ff6a2559c8b8c338c9ad445ae51d04dd9aa90bb44f36447cfa3c4d57f480ac54fe1a5d35b9fad87a3e78b0fec4bfd3ec8866d069edd276d64ec3c50f6dd215b8e24b381157ee7149d624ce09c9465c199ff04cecfd322c6ab2dcd022d07b41f09630887981857f13f650613d0e6b56df7e39c5573eb46fd2e2b58b94ae16c4555efc9c6b658b4554337c9fb76e60e7e5ef38218151996aaa4b4fb4737b0d3d6ca2f8a74b2fcd4ac22e97e5e42cecc790cf0fdc203f51e3225af768b6397d8f42082c1c80d8d520da13dc3ad9c87375898c7598a9bb08fd73092924866613efef853fa4dca8a52dbc07676cf86ba5cd055e9f01d1bc094fe5b1b09bd48eb9906cf1d549d024ef6cb0bc4b63f8be1def309bb1d4d63f22ac2ccf86389bb213e82eced58e4975780c749aa93f6e6d5dae9c0e38994aecba3224c3000000010005582e3530390000031e3082031a30820202a0030201020204518bb8fb300d06092a864886f70d0101050500304f310b300906035504061302434e310b3009060355040813025348310b30090603550407130253483110300e060355040a1307636f6e6e736563311430120603550403130b636f6e6e7365632e636f6d301e170d3133303530393134353535355a170d3430303932343134353535355a304f310b300906035504061302434e310b3009060355040813025348310b30090603550407130253483110300e060355040a1307636f6e6e736563311430120603550403130b636f6e6e7365632e636f6d30820122300d06092a864886f70d01010105000382010f003082010a02820101009b738f7e100eecffe6673968c77df20540b30887f6e7aba6a61f5e8adbdad86bb2afe43aea69ed26811b5ee957fcf62b627f7287d59a91ff3c154b50df75aeda1578a8379be5cf69cffba2c8d72d2e88421fc81331a2188b6cb45e44cd7e2ed7fbf88d8f846aacf4f3a8e6c2f346f05129f72359231aa015abe29b5830609fd8b7dafdafa9821a43eaf7f38e7ec03cc6c994231696506b1d740f4a05b28e9a2475cdaf9d45b8e78a0e9b66a07882ddf6e484bfb111fcbae33af9f6c400de0674364ca9dab32f3812c6d41e88c346514de1bc7a170c817c2c89f3dcef4a390c7575583feaa08ea2cb4499719627fb8c6ee302b5d0c46bc2610526ed8d247371c50203010001300d06092a864886f70d010105050003820101009aa41c0dc58eb29a38f77855b0c7d0e8c02219bdfce74e874b54a0d9469ed880d4775e1555f35f3ab68c21437cb59f4568eb2efe5274ea75abec1f0f64fe05c4f149ac77637a7fcc8a2ee83dee65cb5a0091e3c50ad79fe9bd14c64f472d9ab223716c4210e78f55937d45420a6a5e9f0c0c9b6ad137e2d1fefab0785b33c325cf73ba3208488985d98845afb0fd06a5da9170b47a8a946fea5aaae23ae6ee38701253b9960253728052ab299101f8fb1df4e82b685e9611aaab59a70c52c15ed8571c4498724fa3037520f6b173a8595a6f93fe8f3ebe23fa12eea2e14efb7a04789cf4e9b0012959837cbabc8d778c102d7de36eef1f97d46d527d28e11f472509eb9c55902b56d748929bf0e2c109d8d644c0'::bytea, E'https://shikey-dev-ed.my.salesforce.com?so=00D90000000r4kw', E'https://sso.maxkey.org/maxkey/saml', E'https://sso.maxkey.org/maxkey/saml', 15, E'persistent', E'original', NULL, E'https://sso.connsec.com/sec/saml', E'no', E'Redirect-Post', E'RSAwithSHA1', E'SHA1', E'', E'1');
INSERT INTO mxk_apps_saml_v20_details (id, certissuer, certsubject, certexpiration, keystore, spacsurl, issuer, entityid, validityinterval, nameidformat, nameidconvert, nameidsuffix, audience, encrypted, binding, signature, digestmethod, metaurl, instid) VALUES (E'824007723908595712', E'cloud.tencent.com', E'EMAILADDRESS=qcloud@tencent.com, CN=cloud.tencent.com, OU=Tencent Cloud, O=Tencent Technology (Shenzhen) Company Limited, L=shenzhen, ST=guangdong, C=CN', E'Thu Aug 15 14:24:31 CST 2019', E'\\xfeedfeed0000000200000002000000020011636c6f75642e74656e63656e742e636f6d00000170873ce10a0005582e3530390000045f3082045b30820343a003020102020900fd966bf8b3e999fe300d06092a864886f70d01010505003081c3310b300906035504061302434e3112301006035504080c096775616e67646f6e673111300f06035504070c087368656e7a68656e31363034060355040a0c2d54656e63656e7420546563686e6f6c6f677920285368656e7a68656e2920436f6d70616e79204c696d6974656431163014060355040b0c0d54656e63656e7420436c6f7564311a301806035504030c11636c6f75642e74656e63656e742e636f6d3121301f06092a864886f70d010901161271636c6f75644074656e63656e742e636f6d301e170d3138303831353036323433315a170d3139303831353036323433315a3081c3310b300906035504061302434e3112301006035504080c096775616e67646f6e673111300f06035504070c087368656e7a68656e31363034060355040a0c2d54656e63656e7420546563686e6f6c6f677920285368656e7a68656e2920436f6d70616e79204c696d6974656431163014060355040b0c0d54656e63656e7420436c6f7564311a301806035504030c11636c6f75642e74656e63656e742e636f6d3121301f06092a864886f70d010901161271636c6f75644074656e63656e742e636f6d30820122300d06092a864886f70d01010105000382010f003082010a0282010100bbcf628cb51e864b8233c1f1582d250b0ab2abafa8945519715219f4cbf0a3a565c6837d67c2f5d898965a0b08d4968ad3777a580e64ad99de31a0bdf1ac6167a97d31a8ac3b4bebdb07dc28e6d487c30d79be48983da9e3b2079a8978a104107a8efb15f3ee22b9593c240df1f7dd3fd3089cfd9b8a221088e262c269060b5dbb18a2950f439a7e77090263da58c4ffb38ce41ab61034723ccacb3a7d8a8da9707dafb63ed1cccfa3e2c2d3b130be3867e1ee4f4b40ee7f7ecc104d02abd41e2d9ad23c0aaee950fd05b9dd582e3329a1dfcd455bf5ff1205e9c2453fc40045f982e3914f8c74e839189755457c8628bc9781245f0d9b0103bec2aa1d5c96990203010001a350304e301d0603551d0e041604143a7bc9c5513ee8285f8b6ce6051f6d34591e48d3301f0603551d230418301680143a7bc9c5513ee8285f8b6ce6051f6d34591e48d3300c0603551d13040530030101ff300d06092a864886f70d010105050003820101004021a6438e008b916aba7c5a69fd58b074406d2db28d371d8adbccfdd644d9344fa57a961a82a59020fa531a8ebd1a63bd41d7ff9a4b2963763cd10dcca543b4f55de0b22a974011c3e597f2447c26a838c3b9d2c0d521b3323313fb8f17b8cab87dda273b5a397f20e1fcccbdc352ee459cd6c39644d091292a05ead729d0633d2e122a7b2ab51550da004b69fd8d3f003dfb35e8ce29e5546921896e82707047d3f66d96dafbd7d1fd23d36bb157e12f2c53ae3dc063d1fb8f6ebe273693073c14fe805c6bab25985dee6678e23e7cab433f2d79bfeb08b252c959fc8d2e1a1c6645abf4713433e13d5d5ca761da9259070cfcc8cbf63fa7eec5c16551e47a00000001000a6d61786b65792e746f7000000172e2244e9d00000500308204fc300e060a2b060104012a021101010500048204e806641c63e5bb856ba23b817f54672ce0b78f2abf75fd349a1aedf1f21ae4c77160401a07ffd05ea695e511b25373d31a4cee5c4e705af4573145365c56681fca197aa40933d62329d184cb69428e04a71daa09f99c9d44882b0c3f69b320a30c819b1780b857c50505e91a3e4e942bdde26db97bdeb9393a95bd4dc3dbf63c27b0420da5a381431f2b61353460c7515743aac12f274d3b2bc8b5d26395ac6e5357d9c9a00c901f0adcc80709ccdb33067b279b5b134216aa01c0019a76c863cbe78ddcecc494635f2d5b785b26bf870b0763fa25faeab1cbcac7e50e80206063e6a1753e0db12b552f66e23831f70701082acde233de5ace4c13c1e42f2112dd08c9a340844ba4b6e50e8ded0adf4311be37ccb5250a5c6bd0bf698929e07a28e73d4d23684a8e5b98bfc48f231d46d0c00d7d9adcc4ec5ec8f7a9291222eec9f35020ef1878e89e2815695f7e306ae9debf24aaf287ec007bc1fd1098e2c8cb248642024028db5aafa210b1a04c784f12ad7cbf99250f945af84c019872e5dae122803a71e09be508ebf4ccd696ebba5a3bd8266b0870eadd61c6fbafeb511fc1de943cfb67924e2b7ddb0b044c732b636bc357cffb91edf1aec79631e5a3f0efed5288961da946f1a049648038d4d1cccf9d58458047465a705aeb6b0b3d33d66cd73c9d9d684da7f5b55a9f6b6a1f0f6fdf5da2127a7470fc5231d742798d40fa51f05b9ed534ee786a0412b78db043635da4766975ede6b6db1440327a647fe456479763307d28756b7bb4752d34187779af57da01602a0d09f34b298b0ccc377d9424c63aee2b49718fb2a048dbbc104b41bac81e237090b8964181bffb195688d64952da818270751bc5a733dfcd5912bcd9139f1fe1482f31aa1b2b3db67328f1a33616b38005ad2f1029b3f92ee3eb47b9805f539d24a7319272a03d6fc472e0c1eda4bd722546830053aae37f171baf017cd4e4c45e8b7f03a56846bfcb1a66c84c259fdb6af02219c2c4c23e51e761c304beed9b3b9c14ce6d649faad52e8f22bc2628d794ff7ce2129044af358c21e73c8e9ce9b645c20555781a8f1d0d8f82e3583407dea9693aa83027ba781815674023a7ca045cf7a14a1a653ac021047bbed5b0ff9f3776371d9795ec40b5b996d61758d244027f012dec5f132c70e921a8e235409f62835b6c922c72ffa9449dfac35c34682113b8b511b63ba348001bc97e602ff12caa6255e8b2519c6faaaef917a4c0a9930ab8a1afeee205a2e0fbe8ac09e385f4b5a2ea60836db13fac1e30cb15d76b7dec4646bd28678a358bfe76e977878b9a1c6d7bc493e0996f730aae7373b5a84549ae9606882585060635e345b0b77e53d42342bd355cbbef797d30ac25ea4e0c75e467a68e7d522d876695791ffa1c926fc823058e8d186a6c441b2b8520de415ce88fc2850b51cddb1f06baea46795a89a081ea60548cda8a34854d61104ed7c2c9213b8873d8c634b94249ca83e97832b50246ab28ef352085bd9a5f6fba2bff395a88bc246bd0efce49ba9d0d6ad6fc8dbd736fb0692a0888b9d2ca924cb4fb2222b49e052e66ec18a28734f54593304c1d4211c7726999520048f441a1ec1746e5ea54c4a22f8f1f00a03516f6a70c8bd64d0438f40c59c3be5e46646f3e196b6edaff3f9ca64f8518f71edd9ce1f609143492bc650ec8ab8fa24347cefa0b0b38482ee34fda124e44cf7220c616f4fa8775a8053bf6b0385a591ff432c070fbc91ed20e97e97294b09c63000000010005582e353039000003823082037e30820266a00302010202045e572d8b300d06092a864886f70d01010b05003081803120301e06092a864886f70d01090116117368696d696e677879403136332e636f6d310b300906035504061302636e310b300906035504080c027368310b300906035504070c027368310f300d060355040a0c066d61786b6579310f300d060355040b0c066d61786b65793113301106035504030c0a6d61786b65792e6f7267301e170d3230303232373032343733315a170d3430303232373032343733315a3081803120301e06092a864886f70d01090116117368696d696e677879403136332e636f6d310b300906035504061302636e310b300906035504080c027368310b300906035504070c027368310f300d060355040a0c066d61786b6579310f300d060355040b0c066d61786b65793113301106035504030c0a6d61786b65792e6f726730820122300d06092a864886f70d01010105000382010f003082010a0282010100b333dcf851f74ac4194fa1408d8a96f7db57df0950b9e8bf7adfdf8d99eac6674745ad9547195e4d3d5c51fe1f93ee68c1df551d8740877e4f58ee70c4a6e97c2671ef6280e00fb21b2b2111d8866a4b44a86893993ce80e973e3da0f538add1447ebf685f5ad1b9ea1b7bb452200a70223503c0f1fe5f31f92f532f6e63bacc38981aac56509dd7d022aab5354240702d90527c2cc11d5718b794b7f6a68f7844e9017785dcfe948cd5c3c915d01e4cd644da09a11d7d3fa2d091e90ab95c60d5310f3f45020b92e1496e373ca8327b080dd8e1a13bd29cfbd83063e10e3c487d80be4af9244bfbc20b34024deeed4e86877ab911f397d1933db371079a06070203010001300d06092a864886f70d01010b05000382010100186f61713baf5304cf90bf269018143469bc3dcc44dba8ce169065f3d3438f91974cebf86af8c05afa322efc10e44d582fcde6466b64b7de6ba67275a6a40f969a5ed04ee0a5a7d0a027512b2896fe033b093f3a10c5c318dbf5f79b5fcf228f4e570845ec0e81b3b01dcc5175136055cf2239441d09ce1ffe403905d9db75b1934cde5cba61028222ad9a00c1ea89e21940bf9f499a104f7faa1a9de3118fa9945998f25342661737e5070ccaeeca70b548e82b5172767fbe636c1fd1cc59bea469cada5c241549c2103f1100461dfea6b9c89497e2204a0c228deb18f5008a812ff2d30e009e3bdb4956f03fcdefe197c082ed1045691216c40a0cde8d372d2b1e46503a751e24ab6b29fb2152b3709804c31d'::bytea, E'https://cloud.tencent.com/login/saml', E'cloud.tencent.com', E'cloud.tencent.com', 15, E'persistent', E'original', NULL, E'cloud.tencent.com', E'no', E'Redirect-Post', E'RSAwithSHA1', E'SHA1', E'', E'1');
INSERT INTO mxk_apps_saml_v20_details (id, certissuer, certsubject, certexpiration, keystore, spacsurl, issuer, entityid, validityinterval, nameidformat, nameidconvert, nameidsuffix, audience, encrypted, binding, signature, digestmethod, metaurl, instid) VALUES (E'824007893782102016', E'auth.huaweicloud.com', E'CN=auth.huaweicloud.com, OU=Service Provider Operation Dept, O="Huawei Technologies Co., Ltd", L=ShenZhen, ST=GuangDong, C=CN', E'Sun Jun 18 21:25:00 CST 2028', E'\\xfeedfeed000000020000000200000002001d68747470733a2f2f617574682e687561776569636c6f75642e636f6d2f00000178405113a50005582e353039000005ed308205e9308203d1a00302010202043c74828a300d06092a864886f70d01010b05003081a4310b300906035504061302434e31123010060355040813094775616e67446f6e673111300f060355040713085368656e5a68656e31253023060355040a131c48756177656920546563686e6f6c6f6769657320436f2e2c204c746431283026060355040b131f536572766963652050726f7669646572204f7065726174696f6e2044657074311d301b06035504031314617574682e687561776569636c6f75642e636f6d301e170d3138303632313133323530305a170d3238303631383133323530305a3081a4310b300906035504061302434e31123010060355040813094775616e67446f6e673111300f060355040713085368656e5a68656e31253023060355040a131c48756177656920546563686e6f6c6f6769657320436f2e2c204c746431283026060355040b131f536572766963652050726f7669646572204f7065726174696f6e2044657074311d301b06035504031314617574682e687561776569636c6f75642e636f6d30820222300d06092a864886f70d01010105000382020f003082020a028202010098ac1ce6de2ce3ecda627878905caee31997d163bd141e0e6a1fc6039c21c9b26edeaa943a80bfbdbbe4930c41f405704a311f71aa7024d8aaf49a4a71cf689075c658cf20a016b5dee9d7299ebdc4b21761dd099f203c92a0dd0ebe663c138a9292fe766bef19a9510d16bf0464819ef37ec9405becb93c28240eb8261231bddab2c0ae3f223e19ae8da8d76933d02951ee64cc41cd2ef7e6ea38ca3570604dfed261381d36632beea7e857eef8984bce170a1ae966ad3ffaa878ac31b217019c847a00436afa266fee73bbf0944308a2e4800fad14f0c1e818a46e3eb982767077eb51d1eac3d9520926d0ceed725b5012e33075eac8e81d9755af163292d96cc0d989d7f332447e5b3bdd1eda4bd5c15e25df81e2e47105bc51632fc4c0b1b378986bc0f5f828857a77d31f7b51d3d557c26234d00a663759484746f71aab4d17dee3e2d083f8732cd4b0b24a379c39c7f2a84282d6fca888a9437b3b9e209ae7701059847cda51158a896cfdd6d653da987a5755bc63408094aa1cb07ba8bc1c416efcfb6575e38e8a850ab3a8f78b23800d19a2c52b0f1f1b3821f3944a3a3ac87ad6f8c003999a1aeb509ad1838ec361042336fde0943839de28cb3c5ba7cd1a94a2a2e986b6755e9100e32db53ad4cfe8e31800cd2548e8f5823bdbb9b4c3a3c5ce42ce581ad4cec879f8090e0647c34da3b52bc15126a191c0f8029b0203010001a321301f301d0603551d0e04160414edd39416f5dc978bb78c7a428e1f46e7e312ab90300d06092a864886f70d01010b050003820201000aff73833520c7143cb7d95d3979a2af1cd23ab1f13022fc48ab2ef9cf98e21a0799ae4b163ca5bfac7be8d593005484e8682a7ee348fe03e3ff6016a8e6c0bec1ddf25b0f8c9f7a66849a4e64bc36bb54e87b93d4b73e0a655f786777fc6f8ab294040a383625e06b7f2130f41f0a500415db40d0ba419f007b4a2903ce6662a6d109b7131582797cf54d1d8a3fe2eb867cbfc86e3783889550aabae47147b39711cd1934891d3f34ba60825e7e3a9d2bc4cc419fe6c2ae72418b49fdfcf20c7d6361904065f81fbe1227cf510c5068e12c9f14e0168d4ee24b0af610c570b6ebfb5a820e0548324c82d7130106290280bbc8773cb749704d9dd20452af9080e391c4b96ad56aab7cb14edb64f1666f17681e60dfa50c9393c6a151c69e300b45e0078c2d02e6c22228c25281038f77bd579904acc371bd36c30a7ff1f7c495e4abf6faef696cfe5d4906c966e760c09369395252e47ffd69e08ed61ce7e6e593690e38f5ad33fa4a201cb562eda97214dbc7cb6b6b00fb31d703969c0c63a6e9e22b3267b91e9b15fcaa14396d4c5c6ba02b9f73a1f7ae7821431917dbca84b6963d125be09b2556bbd822dfdf13e1da7587d1c2bd75efb0c82c7cb88d0a18fc95e08f7f5c12c786f91bdd73da51f9e4cd891cac6ff7f5c39ac6e3c5cfe85a5f023596f23deb8cef9938307438dd7ffd1ab00d3d4bb1042b62b2cd751110ce00000001000a6d61786b65792e746f7000000172ead6fd5e00000500308204fc300e060a2b060104012a021101010500048204e82934c231aa1c5d9b03cc22e9455d7ac90295eca183ec3400a99b2c3ffb09e015bdcf7f60c6023b33351843e11b3f2c0465225e526f76f6a7e587095b5c2b741fb3ee7a08de7ef4c3468e8fb74db9b4d027c331347d34e457042959dc7eec6ba0831c45d13b0c74b4250e21f043d0500b70d360ee596f85e64babe0c54d87960423526035d7a1dfa751dc2d06eac31c645a0c637743a43468ddc7b134b602a64e08dc70e4b923014487be7c8abf56bdf6903da70a7620cb9e6fc50f0a435a3803171ae566b82207f3db794e13691cba809eb714f005e8c8feaab98bd32f75f2d90c8b2081040e000abada82473ed88de42b6d88d57421fe810c89a8fbcd8a22e9c3568bdd3aaa5fe310422cd28664b2cad7bd7078a977396c4ff7be643c07fe1fe40d39755720e098f883ca1de70e3727519268762a2698c781390b6b0b5e6aa09c6e97ac6156d74c7b7f8997cb7f4e7e00f623132ba6a261d14d71461a29d350ffe3bacd66209f50d3ac7e29415f34c7c91213899feb3ece4133c73d212ffac8b4149bbc8a7427154527b55f150dbd8365a52a0a63f13e6b117e35641eff1d9ed3b2cfa50ae29684d60ba578aab80a5f9204874859de215f96eaa57da5d68725a090af11992866aa07d5b1773de45e4dbfe499a62085af4c40f816f819b6afa91e010fa3512c391759de15d6f34a6e3d6e316dda2e0d10880037837ffbe0ecf9e810d5874e5ba31fdaddd8b7c35507366d7ae5f94c2356777503cfd0fc44a98abcd0fe6e03567b3742b6826c8eaee9d2864cda29540790d18d59c75651dbc94b10693231141b97603eeb1d06e4315c50e11b7b9bfcc94f5d5408ec336ad24b0a171b365359c470d958f17f897d467a907ffef631cabb0755d01d0be9f62b4469d0e2f770a5656f118ee669f8b7e4b7743e102eb76f6249a0b12f09307751a887101e93440b320a3b002712b9edc520665301da6f7de9bdb86cd76ee3c9793ca4a913b0eb1b5ce7de52327cdccd6fb0bbad380c530101a88e938cbe7204ca01e65993b6a39e267014ee7bc9f2fbb52ec93410512bba45297a9dce86c4812af3976594eb552f16e4334c48c42f3986abebb622ac603394239f3165e33a4c751a2992fb434a9c7f72b9b39466d14437bd9e35244eb48597c479dbce23ebf0cde42ced753c26bf7f2fcadf7d8b7b324226ae2598786cb914ac7da1152437e1ca03df86a4d2e1e92f24331ac9e8c73dad5597a0fafd8d28f455651a871cdb558218bd572a6423eae4e81a9d54a70ed1de11193baef1a80173fcf6223965a71f478182273fb7c71b43375854e30754b187326ebec21bc14cf96f1ccb2d1fbb2ca29da62de3b1ad584959ed2f69ffd87aff5ec22340e804dda0a0a26ca7314d1ceb79b815eda9e6b3707674eacc20045ff9ac411715f1c031e7deb3d20ec044b6d92ccf84f0052397189e8e6d1d3053afaf7418cc510b5ac675cceee155cbbfbcca426f8c9566e18f7800bc182258a93db1622d39599e8d0e299b0e7c168d5ce6cc4b16445cbe3590753571238b346940d66ac8ed6855f952b6696fc6fbc165951c62d38affa1f269acb395e2f952aea3d940422a970bea7d458d90965d2de8ce7b0223e9ed5fdfbf561b661e138f282384d40f75172d924ee6dc8a0cc89a7ee0fea867b1daa83386a1e22186bbd17b513ce10986c6d8fc7eb06915002a06a4dc494b63a85e069a7f300e78cf5235f1a4dc0b0f35e63b7e385a591ff432c070fbc91ed20e97e97294b09c63000000010005582e353039000003823082037e30820266a00302010202045e572d8b300d06092a864886f70d01010b05003081803120301e06092a864886f70d01090116117368696d696e677879403136332e636f6d310b300906035504061302636e310b300906035504080c027368310b300906035504070c027368310f300d060355040a0c066d61786b6579310f300d060355040b0c066d61786b65793113301106035504030c0a6d61786b65792e6f7267301e170d3230303232373032343733315a170d3430303232373032343733315a3081803120301e06092a864886f70d01090116117368696d696e677879403136332e636f6d310b300906035504061302636e310b300906035504080c027368310b300906035504070c027368310f300d060355040a0c066d61786b6579310f300d060355040b0c066d61786b65793113301106035504030c0a6d61786b65792e6f726730820122300d06092a864886f70d01010105000382010f003082010a0282010100b333dcf851f74ac4194fa1408d8a96f7db57df0950b9e8bf7adfdf8d99eac6674745ad9547195e4d3d5c51fe1f93ee68c1df551d8740877e4f58ee70c4a6e97c2671ef6280e00fb21b2b2111d8866a4b44a86893993ce80e973e3da0f538add1447ebf685f5ad1b9ea1b7bb452200a70223503c0f1fe5f31f92f532f6e63bacc38981aac56509dd7d022aab5354240702d90527c2cc11d5718b794b7f6a68f7844e9017785dcfe948cd5c3c915d01e4cd644da09a11d7d3fa2d091e90ab95c60d5310f3f45020b92e1496e373ca8327b080dd8e1a13bd29cfbd83063e10e3c487d80be4af9244bfbc20b34024deeed4e86877ab911f397d1933db371079a06070203010001300d06092a864886f70d01010b05000382010100186f61713baf5304cf90bf269018143469bc3dcc44dba8ce169065f3d3438f91974cebf86af8c05afa322efc10e44d582fcde6466b64b7de6ba67275a6a40f969a5ed04ee0a5a7d0a027512b2896fe033b093f3a10c5c318dbf5f79b5fcf228f4e570845ec0e81b3b01dcc5175136055cf2239441d09ce1ffe403905d9db75b1934cde5cba61028222ad9a00c1ea89e21940bf9f499a104f7faa1a9de3118fa9945998f25342661737e5070ccaeeca70b548e82b5172767fbe636c1fd1cc59bea469cada5c241549c2103f1100461dfea6b9c89497e2204a0c228deb18f5008a812ff2d30e009e3bdb4956f03fcdefe197c082ed1045691216c40a0cde8d372ddbf89278dc1985e19abe2045584e78e25037cc69'::bytea, E'https://auth.huaweicloud.com/authui/saml/SAMLAssertionConsumer', E'https://auth.huaweicloud.com/', E'https://auth.huaweicloud.com/', 15, E'persistent', E'original', NULL, E'https://auth.huaweicloud.com/', E'no', E'Redirect-Post', E'RSAwithSHA1', E'SHA1', E'', E'1');
INSERT INTO mxk_apps_saml_v20_details (id, certissuer, certsubject, certexpiration, keystore, spacsurl, issuer, entityid, validityinterval, nameidformat, nameidconvert, nameidsuffix, audience, encrypted, binding, signature, digestmethod, metaurl, instid) VALUES (E'824009331925057536', E'urn:alibaba:cloudcomputing', E'CN=urn:alibaba:cloudcomputing, OU=Alibaba Cloud Computing Co. Ltd., ST=Hangzhou, C=CN', E'Thu Feb 02 15:18:06 CST 2119', E'\\xfeedfeed000000020000000200000002001a75726e3a616c69626162613a636c6f7564636f6d707574696e6700000170897570ad0005582e353039000003623082035e30820246a00302010202045c74e82e300d06092a864886f70d01010b05003070310b300906035504061302434e3111300f0603550408130848616e677a686f7531293027060355040b1320416c696261626120436c6f756420436f6d707574696e6720436f2e204c74642e312330210603550403131a75726e3a616c69626162613a636c6f7564636f6d707574696e673020170d3139303232363037313830365a180f32313139303230323037313830365a3070310b300906035504061302434e3111300f0603550408130848616e677a686f7531293027060355040b1320416c696261626120436c6f756420436f6d707574696e6720436f2e204c74642e312330210603550403131a75726e3a616c69626162613a636c6f7564636f6d707574696e6730820122300d06092a864886f70d01010105000382010f003082010a0282010100c38c3e776443441e860d5c039f3886d5049863ed20962a67639db9f1abc58015611e66d4ba8592cfa56875cfb6f4363264bc27f9a0556a04961b6d6e6410a57ef42a55e951d9a8e5e6b0846592f641f969dcdd276ec228a2511f49a2348fc5542f49fe162d3f870c04a5ac1cedb91576bc78fdbad2dbbf2fba6e0541a85f207a62fd3dc89fd6ba1b0c7f0796a51c0035cb02dd7c13831b4e895d5681e3a4573a7c02945ee8d61f97de00bf20d022a599ffc95651cb12dbb8bca3f1050f2c824cac93a127ae35e5e90e1ae2dfaf6cf1b9b9ccc0d68b93903ba93024656961c81da24bfc0a0319a6e7f2c55775a54950a0b9e7814d911ce7061450965f8db9cdab0203010001300d06092a864886f70d01010b050003820101004f24e12e07bce825b6127017768c4171a22ca5ba05e72cf52963034ff956d6500eb0dfd81cbfd4120cbd67d9fdd1673be3329432d5752e975af59ab7f0d6d1f386c54e2cd5635fb215fb0c90c64761b55e0b46a036446080da854a7991ab403f2a42918e7b7c66652347779eae3aff6a93fd9a677bea451370c8ff1f249593278a78b06233576c6f7acbf3380d88b527b451f262c87d5bf3e68d523064f84dada9fd4484d8cf45e8eeffcdcda3eb67508178986bd38e368df54625d14e6bc611436e428059855ac522f3a736321f153ed7777094a30c0928fd5f968b1eaebc780798d2711022f722b7c766b69617dcf8f92c5df4ec6aa22be5340be0ea2b2c4100000001000a6d61786b65792e746f7000000172e222c9fe00000500308204fc300e060a2b060104012a021101010500048204e8d89090b0aae4790cb5e3716196bb2e8756705711252e72f5efe16e3762b3e97e2b81f41edbf85a14ea9a79ebb1e4ab63465d6ca843e91568d9b162f276b61de8520629850563d573d97b0bb113e7501447461761b35d302180d5967d3f90c0a5c58446f0db16de3df87cc2777d1d2c8cf0e874837a9e012485ff6623644e9c859763a65240735199b4df74e17e468992e73c1d24d5efee108d11045c9a15d60e50bd99309f2dfbb6feb8eb5193be890d0ba075583b04f9a9fa23cfb24bf62d7fd2aad817f413915a5fc9de9d66f50ae6ae524340ce602089bc479977bf0e2c009c15fd8e95fa427637e281fba41a5ce339ae8b0b652b7c332e0748db098cfa3c7ff1a94b819fc61971c8344cf57c6da922af7d77433616c5ef9a6480dad42cfde33fc6b590a6c0903f2a57b2a90f4ab54171be7bd96031e429f2ee25f50ce16809b97120d6b458d9da58548830ca8876c2de59fb0af44bc553ad36c51f5da7132227eb5e7af40e17153a8e05e81ea3f1178a48b0c83cb60fd65923c0e7c1a53f81bfe05659d6dcbcd964242b76851a74cbbf9d5e0d54d219356ed42137775752fa865d5731d1c64640265e9769b37eef7ed72254621a7aa89f9f458f1539d9976023e243b37aaf1be7c8edb7d6ac42cd6de0e347e6101df5690b5edd8a610ebbdb801142d1b2c3d1b0760d694bf36715e039b636cfd1868c24f308ac64bb62a1d967fad3954c989cf19f46a750d72ce752eac99ec759a978109251c05aba8a2fa9c4e57039bc1f951653227c6aff4c16ebdd85d6f22abbf52b1a5a18834fab1fee7b89c4fb1932de4e093eb5afd6ede9f0915b263c0a28d1c0f0d52afa9d76dbf34b1815fe7662a672cd6fccf9257a6427c4df721bc0a26f632031eeac8f0daebfd847811661f9e952c9fc405e4e6ed9e5fcadf371997f0d7a0f08d705cdca019519d954ae5977b312b5383eec529f0cb68b8fb22ff70e2dcba643fb9b30fe1d9efc6a6ee3ccd4f4bc2ed5ff6326f6605640c5dedee963b21991a620a657b4e6c22a2ba32652712e8137860ae37ce619883ff75746c8ff2cfe60f3625bfd4c7ff2d2bce5d181b497e3b3102d545cb6fa1ec699f4d37d0c9a740605f64e00a031e5634ac09cfe53b603414b6a0adc12bf2c96675757ce2cb1118ae82f6ef73d070974199ec28556633dd89d4d1ea69d4302b2cf5de76767768ecdc4bd884d0bd2b0f5b6203fca710452f31a15f33991e61b69a2e6a49d6ece4461583ff2c2845ecca5a0b070b20d24dadb65cb60cca023ba73cd0d4d78298f5027e7ed2b8f226c017fd262277b5ae72644fa5ddb4cdc2a8e99919b419cc292373a7992dc08353198d118568658378515049bcb07ee81c9a9bbf5760f52ce89acb3c9bbb3592e865ba2dff7dbda3677a4ab67705edc20a1b1152fd033b418eba9fc6648fe61ca64397ac5c0ab8df72c1459d4b5fbfc513e8c296eaa639791b8a0f376091e96aed152577697f210db55103446e30bbbc8367f3541cfd04ea0280f0df8c8c426c556e8972f6e1c3b4330c7fc6effb69adc4e1a3e3367e6dbf7601c446bccdd0eecc5efbd72cc692cd50072daac5ea8782fbec1cf0930340b0592b270d378d6c401eba83b16996feaac4f906581e4b032f1bc4c2432e431052a734430ef4b4596e4620abbded19cfcea68be820314c0a51454705488f8a75d6e5c84d4510d4ee9478dbbb9b5ce1725216ba88c0ba38e6504df9f1ea0b4385a591ff432c070fbc91ed20e97e97294b09c63000000010005582e353039000003823082037e30820266a00302010202045e572d8b300d06092a864886f70d01010b05003081803120301e06092a864886f70d01090116117368696d696e677879403136332e636f6d310b300906035504061302636e310b300906035504080c027368310b300906035504070c027368310f300d060355040a0c066d61786b6579310f300d060355040b0c066d61786b65793113301106035504030c0a6d61786b65792e6f7267301e170d3230303232373032343733315a170d3430303232373032343733315a3081803120301e06092a864886f70d01090116117368696d696e677879403136332e636f6d310b300906035504061302636e310b300906035504080c027368310b300906035504070c027368310f300d060355040a0c066d61786b6579310f300d060355040b0c066d61786b65793113301106035504030c0a6d61786b65792e6f726730820122300d06092a864886f70d01010105000382010f003082010a0282010100b333dcf851f74ac4194fa1408d8a96f7db57df0950b9e8bf7adfdf8d99eac6674745ad9547195e4d3d5c51fe1f93ee68c1df551d8740877e4f58ee70c4a6e97c2671ef6280e00fb21b2b2111d8866a4b44a86893993ce80e973e3da0f538add1447ebf685f5ad1b9ea1b7bb452200a70223503c0f1fe5f31f92f532f6e63bacc38981aac56509dd7d022aab5354240702d90527c2cc11d5718b794b7f6a68f7844e9017785dcfe948cd5c3c915d01e4cd644da09a11d7d3fa2d091e90ab95c60d5310f3f45020b92e1496e373ca8327b080dd8e1a13bd29cfbd83063e10e3c487d80be4af9244bfbc20b34024deeed4e86877ab911f397d1933db371079a06070203010001300d06092a864886f70d01010b05000382010100186f61713baf5304cf90bf269018143469bc3dcc44dba8ce169065f3d3438f91974cebf86af8c05afa322efc10e44d582fcde6466b64b7de6ba67275a6a40f969a5ed04ee0a5a7d0a027512b2896fe033b093f3a10c5c318dbf5f79b5fcf228f4e570845ec0e81b3b01dcc5175136055cf2239441d09ce1ffe403905d9db75b1934cde5cba61028222ad9a00c1ea89e21940bf9f499a104f7faa1a9de3118fa9945998f25342661737e5070ccaeeca70b548e82b5172767fbe636c1fd1cc59bea469cada5c241549c2103f1100461dfea6b9c89497e2204a0c228deb18f5008a812ff2d30e009e3bdb4956f03fcdefe197c082ed1045691216c40a0cde8d372d353f85d2a47da4611b4ad90c8ba17560d766b120'::bytea, E'https://signin.aliyun.com/saml-role/sso', E'urn:alibaba:cloudcomputing', E'urn:alibaba:cloudcomputing', 15, E'persistent', E'original', NULL, E'urn:alibaba:cloudcomputing', E'no', E'Redirect-Post', E'RSAwithSHA1', E'SHA1', E'', E'1');
INSERT INTO mxk_apps_token_based_details (id, algorithmkey, algorithm, expires, redirecturi, cookiename, tokentype, instid) VALUES (E'824009611043405824', E'$2a$10$C8DZ1RKc5Mj9cNVIxRS0KO95fe0f9761d9cf366e425253b6586e2523ed715104c700582cf8f789da8d99fd', E'DES', 180, E'http://tokenbased.demo.maxkey.top:9521/demo-ltpa/ltpa.jsp', E'ltpa', E'LTPA', E'1');
INSERT INTO mxk_apps_token_based_details (id, algorithmkey, algorithm, expires, redirecturi, cookiename, tokentype, instid) VALUES (E'824010355507200000', E'$2a$10$vvuCfYOPpgyAiK/0des9pece9d58c33de50e6e330ce95f38d47e188a5ab40e01407dd37976c4f2c56cb529', E'DES', 180, E'http://tokenbased.demo.maxkey.top:9521/demo-tokenbase/jsontoken.jsp', E'', E'POST', E'1');
INSERT INTO mxk_apps_token_based_details (id, algorithmkey, algorithm, expires, redirecturi, cookiename, tokentype, instid) VALUES (E'824012456819949568', E'$2a$10$67xkagBJmJ7GOq44ccSPU.9f87327f5460008235ebf5276f2023a8f71158552fcfab0307e3469e99669dba', E'DES', 180, E'http://tokenbased.demo.maxkey.top:9521/demo-tokenbase/sampletoken.jsp', E'', E'POST', E'1');
INSERT INTO mxk_cnf_email_senders (id, smtphost, port, account, credentials, sslswitch, sender, protocol, encoding, status, instid, description, createdby, createddate, modifiedby, modifieddate) VALUES (E'1', E'smtp.maxsso.net', 465, E'support@maxsso.net', E'$2a$10$oGE5qWuqmG0Y.XcTgldHBu3d260c958606d825c8f26f7e7901f56cc645391c563471704defc605569bc13cbf711c27d62aa2ac', 1, E'support@maxsso.net', E'smtp', E'utf-8', 1, E'1', E'', NULL, NULL, NULL, NULL);
INSERT INTO mxk_cnf_ldap_context (id, product, sslswitch, providerurl, principal, credentials, basedn, filters, truststore, truststorepassword, msaddomain, accountmapping, status, description, instid, createdby, createddate, modifiedby, modifieddate) VALUES (E'1', E'OpenLDAP', E'0', E'ldap://101.200.202.61:389', E'cn=Manager,dc=psec,dc=top', E'$2a$10$MO/wNbskXGVApg3S4OAX0u37c8592fc38b5b288f0b85d907ce45832893353abbcf4420d96949c7e39295c2', E'dc=psec,dc=top', E'(uid=%s)', E'', E'', E'MAXKEY.TOP', E'NO', 0, E'', E'1', NULL, NULL, NULL, NULL);
INSERT INTO mxk_cnf_password_policy (id, minlength, maxlength, lowercase, uppercase, digits, specialchar, attempts, duration, expiration, username, history, dictionary, alphabetical, numerical, qwerty, occurances, createdby, createddate, modifiedby, modifieddate) VALUES (E'1', 6, 20, 1, 1, 1, 1, 6, 30, 90, 0, 3, 1, 1, 1, 1, 3, NULL, E'2024-05-03 17:04:08', NULL, NULL);
INSERT INTO mxk_cnf_sms_provider (id, provider, providername, message, appkey, appsecret, templateid, signname, smssdkappid, status, description, instid, createdby, createddate, modifiedby, modifieddate) VALUES (E'1', E'aliyun', NULL, E'您的本次短信验证码是%s', E'maxkeysupport@163.com', E'$2a$10$xRKITSm1Zndkr1XOsEvDs.3a724bbbeda9de170aca7d82b6908df0b5bc2cac1e7de470b5ddd16bf8d1377c1a32c236a3872b7f', E'14860095', E'maxkey', E'', 1, E'', E'1', NULL, NULL, NULL, NULL);
INSERT INTO mxk_group_member (id, groupid, memberid, type, createddate, instid) VALUES (E'622183103330254848', E'ROLE_ADMINISTRATORS', E'1', E'USER', E'2020-12-12 11:03:10', E'1');
INSERT INTO mxk_group_member (id, groupid, memberid, type, createddate, instid) VALUES (E'900182691037577216', E'622181157164810240', E'1', E'USER', E'2023-09-15 22:05:43', E'1');
INSERT INTO mxk_group_member (id, groupid, memberid, type, createddate, instid) VALUES (E'900182912018677760', E'622178881788444672', E'1', E'USER', E'2023-09-15 22:06:36', E'1');
INSERT INTO mxk_group_member (id, groupid, memberid, type, createddate, instid) VALUES (E'900391674608353280', E'622179035744567296', E'1', E'USER', E'2023-09-16 11:56:09', E'1');
INSERT INTO mxk_group_member (id, groupid, memberid, type, createddate, instid) VALUES (E'909567602244714496', E'622178518125510656', E'1', E'USER', E'2023-10-11 19:38:00', E'1');
INSERT INTO mxk_group_member (id, groupid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_1', E'ROLE_ALL_USER', E'1', E'USER-DYNAMIC', E'2022-04-27 15:01:19', E'1');
INSERT INTO mxk_groups (id, groupcode, groupname, category, filters, orgidslist, resumetime, suspendtime, status, createdby, isdefault, createddate, modifiedby, modifieddate, description, instid) VALUES (E'622178269462003712', E'622178269462003712', E'临时用户组', E'static', E'', E'1,101,10101,10102,10103,102,10201,10203,10204,104,105,107,108,109,110,111,,,,,,,', E'16:30', E'23:00', 1, NULL, 0, NULL, NULL, NULL, E'临时用户组', E'1');
INSERT INTO mxk_groups (id, groupcode, groupname, category, filters, orgidslist, resumetime, suspendtime, status, createdby, isdefault, createddate, modifiedby, modifieddate, description, instid) VALUES (E'622178518125510656', E'622178518125510656', E'内部用户组', E'static', E'', E'', E'03:34', E'23:00', 1, NULL, 0, NULL, NULL, NULL, E'内部用户组', E'1');
INSERT INTO mxk_groups (id, groupcode, groupname, category, filters, orgidslist, resumetime, suspendtime, status, createdby, isdefault, createddate, modifiedby, modifieddate, description, instid) VALUES (E'622178881788444672', E'622178881788444672', E'供应商用户组', E'static', E'', E'', E'16:30', E'23:00', 1, NULL, 0, NULL, NULL, NULL, E'供应商用户组', E'1');
INSERT INTO mxk_groups (id, groupcode, groupname, category, filters, orgidslist, resumetime, suspendtime, status, createdby, isdefault, createddate, modifiedby, modifieddate, description, instid) VALUES (E'622179035744567296', E'622179035744567296', E'经销商用户组', E'static', E'', E'', E'16:30', E'23:00', 1, NULL, 0, NULL, NULL, NULL, E'经销商用户组', E'1');
INSERT INTO mxk_groups (id, groupcode, groupname, category, filters, orgidslist, resumetime, suspendtime, status, createdby, isdefault, createddate, modifiedby, modifieddate, description, instid) VALUES (E'622179241118662656', E'622179241118662656', E'CRM用户组', E'static', E'', E'', E'16:30', E'23:00', 1, NULL, 0, NULL, NULL, NULL, E'CRM用户组', E'1');
INSERT INTO mxk_groups (id, groupcode, groupname, category, filters, orgidslist, resumetime, suspendtime, status, createdby, isdefault, createddate, modifiedby, modifieddate, description, instid) VALUES (E'622179422249680896', E'622179422249680896', E'HR系统用户组', E'static', E'', E'', E'16:30', E'23:00', 1, NULL, 0, NULL, NULL, NULL, E'HR系统用户组', E'1');
INSERT INTO mxk_groups (id, groupcode, groupname, category, filters, orgidslist, resumetime, suspendtime, status, createdby, isdefault, createddate, modifiedby, modifieddate, description, instid) VALUES (E'622179552155664384', E'622179552155664384', E'办公自动化(OA)用户组', E'static', E'', E'', E'16:30', E'23:00', 1, NULL, 0, NULL, NULL, NULL, E'办公自动化(OA)用户组', E'1');
INSERT INTO mxk_groups (id, groupcode, groupname, category, filters, orgidslist, resumetime, suspendtime, status, createdby, isdefault, createddate, modifiedby, modifieddate, description, instid) VALUES (E'622179692295749632', E'622179692295749632', E'外包用户组', E'static', E'', E'', E'16:30', E'23:00', 1, NULL, 0, NULL, NULL, NULL, E'外包用户组', E'1');
INSERT INTO mxk_groups (id, groupcode, groupname, category, filters, orgidslist, resumetime, suspendtime, status, createdby, isdefault, createddate, modifiedby, modifieddate, description, instid) VALUES (E'622180463653421056', E'622180463653421056', E'企业邮箱用户组', E'static', E'', E'', E'16:30', E'23:00', 1, NULL, 0, NULL, NULL, NULL, E'企业邮箱用户组', E'1');
INSERT INTO mxk_groups (id, groupcode, groupname, category, filters, orgidslist, resumetime, suspendtime, status, createdby, isdefault, createddate, modifiedby, modifieddate, description, instid) VALUES (E'622181157164810240', E'622181157164810240', E'内部动态用用户组', E'dynamic', E'USERTYPE=''EMPLOYEE''', E'1,101,10101,10102,10103,103,106,10601,1060101,1060102,109,110,104,,,,,,', E'01:30', E'23:00', 1, NULL, 0, E'2020-12-12 20:10:22', E'1', E'2026-07-09 12:24:15', E'内部动态用用户组', E'1');
INSERT INTO mxk_groups (id, groupcode, groupname, category, filters, orgidslist, resumetime, suspendtime, status, createdby, isdefault, createddate, modifiedby, modifieddate, description, instid) VALUES (E'741229197279625216', E'3333333', E'部门分级管理员角色A', E'static', NULL, E'', E'00:00', E'00:00', 1, NULL, 0, NULL, NULL, NULL, NULL, E'1');
INSERT INTO mxk_groups (id, groupcode, groupname, category, filters, orgidslist, resumetime, suspendtime, status, createdby, isdefault, createddate, modifiedby, modifieddate, description, instid) VALUES (E'837332844740083712', E'837332844740083712', E'运维管理组', E'static', NULL, E'', E'00:00', E'00:00', 1, NULL, 0, NULL, NULL, NULL, NULL, E'1');
INSERT INTO mxk_groups (id, groupcode, groupname, category, filters, orgidslist, resumetime, suspendtime, status, createdby, isdefault, createddate, modifiedby, modifieddate, description, instid) VALUES (E'ROLE_ADMINISTRATORS', E'ROLE_ADMINISTRATORS', E'系统管理员组', E'static', NULL, NULL, NULL, NULL, 1, E'admin', 0, NULL, NULL, NULL, E'系统管理员组', E'1');
INSERT INTO mxk_groups (id, groupcode, groupname, category, filters, orgidslist, resumetime, suspendtime, status, createdby, isdefault, createddate, modifiedby, modifieddate, description, instid) VALUES (E'ROLE_ALL_USER', E'ROLE_ALL_USER', E'所有认证用户组', E'dynamic', NULL, NULL, E'00:00', E'00:00', 1, NULL, 0, NULL, NULL, NULL, E'所有认证用户组，已经登录认证的用户', E'1');
INSERT INTO mxk_institutions (id, name, fullname, division, country, region, locality, street, contact, address, postalcode, phone, fax, email, sortindex, logo, domain, fronttitle, consoledomain, consoletitle, captcha, defaulturi, status, description, instid, createdby, createddate, modifiedby, modifieddate) VALUES (E'1', E'马克思钥匙', E'MaxKey(马克思钥匙)单点登录认证系统', E'', E'', E'', E'', E'', E'', E'', E'', E'', E'', E'', 1, E'./assets/logo.png', E'sso.maxkey.top', E'MaxKey统一认证系统', E'mgt.maxkey.top', E'MaxKey身份安全管理系统', E'TEXT', E'', 1, E'', E'1', NULL, NULL, NULL, NULL);
INSERT INTO mxk_localization (id, property, status, description, langzh, langen, instid) VALUES (E'1', E'global.title', 1, E'1', E'Max<span style=''color: #FFD700;''>Key</span>统一认证系统', E'Max<span style=''color: #FFD700;''>Key</span> Single sign-on System', E'1');
INSERT INTO mxk_localization (id, property, status, description, langzh, langen, instid) VALUES (E'678393989128257536', E'global.consoleTitle', 1, NULL, E'Max<span style=''color: #FFD700;''>Key</span>身份安全管理系统', E'Max<span style=''color: #FFD700;''>Key</span> Secure Management', E'1');
INSERT INTO mxk_organizations (id, orgcode, orgname, fullname, type, level, parentid, parentcode, parentname, codepath, namepath, description, status, createdby, createddate, modifiedby, modifieddate, address, postalcode, phone, fax, sortindex, division, country, region, locality, street, haschild, contact, email, ldapdn, instid) VALUES (E'1', E'1', E'马克思钥匙', E'马克思钥匙sadf', E'company', 0, E'1', NULL, E'马克思钥匙', E'', E'', E'WorkWeixin', 1, NULL, E'2014-12-28 16:41:30', NULL, E'2014-12-28 16:41:30', E'', E'123123', E'123123', E'', 1, E'', E'中国', E'北京', E'北京', E'北京', NULL, E'', E'shimin@qq.com', NULL, E'1');
INSERT INTO mxk_organizations (id, orgcode, orgname, fullname, type, level, parentid, parentcode, parentname, codepath, namepath, description, status, createdby, createddate, modifiedby, modifieddate, address, postalcode, phone, fax, sortindex, division, country, region, locality, street, haschild, contact, email, ldapdn, instid) VALUES (E'101', E'101', E'产品部', E'产品部', E'department', 0, E'1', NULL, E'马克思钥匙', E'/1/101', E'/马克思钥匙/产品部', E'', 1, E'admin', E'2014-12-28 16:41:30', NULL, E'2014-12-28 16:41:30', E'', E'', E'', E'', 11, E'', E'', E'', E'', E'', NULL, E'', E'', NULL, E'1');
INSERT INTO mxk_organizations (id, orgcode, orgname, fullname, type, level, parentid, parentcode, parentname, codepath, namepath, description, status, createdby, createddate, modifiedby, modifieddate, address, postalcode, phone, fax, sortindex, division, country, region, locality, street, haschild, contact, email, ldapdn, instid) VALUES (E'10101', E'10101', E'云身份安全部', E'云身份安全部', E'department', 0, E'101', NULL, E'产品部', E'/1/101/10101', E'/马克思钥匙/产品部/云身份安全部', E'', 1, E'admin', E'2014-12-28 16:50:10', NULL, E'2014-12-28 16:50:10', E'', E'', E'', E'', 111, E'', E'', E'', E'', E'', NULL, E'', E'', NULL, E'1');
INSERT INTO mxk_organizations (id, orgcode, orgname, fullname, type, level, parentid, parentcode, parentname, codepath, namepath, description, status, createdby, createddate, modifiedby, modifieddate, address, postalcode, phone, fax, sortindex, division, country, region, locality, street, haschild, contact, email, ldapdn, instid) VALUES (E'10102', E'10102', E'IAM产品部', E'身份管理和认证产品部', E'department', 0, E'101', NULL, E'产品部', E'/1/101/10102', E'/马克思钥匙/产品部/IAM产品部', E'', 1, E'admin', E'2014-12-28 16:50:30', NULL, E'2014-12-28 16:50:30', E'', E'', E'', E'', 2, E'', E'', E'', E'', E'', NULL, E'', E'', NULL, E'1');
INSERT INTO mxk_organizations (id, orgcode, orgname, fullname, type, level, parentid, parentcode, parentname, codepath, namepath, description, status, createdby, createddate, modifiedby, modifieddate, address, postalcode, phone, fax, sortindex, division, country, region, locality, street, haschild, contact, email, ldapdn, instid) VALUES (E'10103', E'10103', E'零信任产品部', E'零信任产品部', E'department', NULL, E'101', NULL, E'产品部', E'/1/101/10103', E'/马克思钥匙/产品部/零信任产品部', E'', 1, E'admin', E'2014-12-28 16:51:02', NULL, E'2014-12-28 16:51:02', E'', E'', E'', E'', 3, E'', E'', E'', E'', E'', NULL, E'', E'', NULL, E'1');
INSERT INTO mxk_organizations (id, orgcode, orgname, fullname, type, level, parentid, parentcode, parentname, codepath, namepath, description, status, createdby, createddate, modifiedby, modifieddate, address, postalcode, phone, fax, sortindex, division, country, region, locality, street, haschild, contact, email, ldapdn, instid) VALUES (E'102', E'102', E'项目部', E'项目部', E'department', NULL, E'1', NULL, E'马克思钥匙', E'/1/102', E'/马克思钥匙/项目部', E'', 1, E'admin', E'2014-12-28 16:41:46', NULL, E'2014-12-28 16:41:46', E'', E'', E'', E'', 2, E'', E'', E'', E'', E'', NULL, E'', E'', NULL, E'1');
INSERT INTO mxk_organizations (id, orgcode, orgname, fullname, type, level, parentid, parentcode, parentname, codepath, namepath, description, status, createdby, createddate, modifiedby, modifieddate, address, postalcode, phone, fax, sortindex, division, country, region, locality, street, haschild, contact, email, ldapdn, instid) VALUES (E'10201', E'10201', E'华东项目部', E'华东项目部', E'department', 0, E'102', NULL, E'项目部', E'/1/102/10201', E'/马克思钥匙/项目部/华东项目部', E'', 1, E'admin', E'2014-12-28 16:49:18', NULL, E'2014-12-28 16:49:18', E'', E'', E'', E'', 11, E'', E'', E'', E'', E'', NULL, E'', E'', NULL, E'1');
INSERT INTO mxk_organizations (id, orgcode, orgname, fullname, type, level, parentid, parentcode, parentname, codepath, namepath, description, status, createdby, createddate, modifiedby, modifieddate, address, postalcode, phone, fax, sortindex, division, country, region, locality, street, haschild, contact, email, ldapdn, instid) VALUES (E'10203', E'10203', E'华北项目部', E'华北项目部', E'department', NULL, E'102', NULL, E'项目部', E'/1/102/10203', E'/马克思钥匙/项目部/华北项目部', E'', 1, E'admin', E'2014-12-28 16:52:45', NULL, E'2014-12-28 16:52:45', E'', E'', E'', E'', 2, E'', E'', E'', E'', E'', NULL, E'', E'', NULL, E'1');
INSERT INTO mxk_organizations (id, orgcode, orgname, fullname, type, level, parentid, parentcode, parentname, codepath, namepath, description, status, createdby, createddate, modifiedby, modifieddate, address, postalcode, phone, fax, sortindex, division, country, region, locality, street, haschild, contact, email, ldapdn, instid) VALUES (E'10204', E'10204', E'华南项目部', E'华南项目部', E'department', 0, E'102', NULL, E'项目部', E'/1/102/10204', E'/马克思钥匙/项目部/华南项目部', E'', 1, NULL, E'2014-12-28 16:41:30', NULL, E'2014-12-28 16:41:30', E'', E'', E'', E'', 3, E'', E'', E'', E'', E'', NULL, E'', E'', NULL, E'1');
INSERT INTO mxk_organizations (id, orgcode, orgname, fullname, type, level, parentid, parentcode, parentname, codepath, namepath, description, status, createdby, createddate, modifiedby, modifieddate, address, postalcode, phone, fax, sortindex, division, country, region, locality, street, haschild, contact, email, ldapdn, instid) VALUES (E'10205', E'10205', E'西北项目部', E'西北项目部', E'department', NULL, E'102', NULL, E'项目部', E'/1/102/10205', E'/马克思钥匙/项目部/西北项目部', E'', NULL, NULL, E'2014-12-28 16:41:30', NULL, E'2014-12-28 16:41:30', E'', E'', E'', E'', 4, E'', E'', E'', E'', E'', NULL, E'', E'', NULL, E'1');
INSERT INTO mxk_organizations (id, orgcode, orgname, fullname, type, level, parentid, parentcode, parentname, codepath, namepath, description, status, createdby, createddate, modifiedby, modifieddate, address, postalcode, phone, fax, sortindex, division, country, region, locality, street, haschild, contact, email, ldapdn, instid) VALUES (E'10206', E'10206', E'西南项目部', E'西南项目部', E'department', NULL, E'102', NULL, E'项目部', E'/1/102/10206', E'/马克思钥匙/项目部/西南项目部', E'', NULL, NULL, E'2014-12-28 16:41:30', NULL, E'2014-12-28 16:41:30', E'', E'', E'', E'', 5, E'', E'', E'', E'', E'', NULL, E'', E'', NULL, E'1');
INSERT INTO mxk_organizations (id, orgcode, orgname, fullname, type, level, parentid, parentcode, parentname, codepath, namepath, description, status, createdby, createddate, modifiedby, modifieddate, address, postalcode, phone, fax, sortindex, division, country, region, locality, street, haschild, contact, email, ldapdn, instid) VALUES (E'103', E'103', E'销售部', E'销售部', E'department', NULL, E'1', NULL, E'马克思钥匙', E'/1/103', E'/马克思钥匙/销售部', E'', 1, E'admin', E'2014-12-28 16:42:41', E'admin', E'2014-12-28 16:42:41', E'', E'', E'', E'', 3, E'', E'', E'', E'', E'', NULL, E'', E'', NULL, E'1');
INSERT INTO mxk_organizations (id, orgcode, orgname, fullname, type, level, parentid, parentcode, parentname, codepath, namepath, description, status, createdby, createddate, modifiedby, modifieddate, address, postalcode, phone, fax, sortindex, division, country, region, locality, street, haschild, contact, email, ldapdn, instid) VALUES (E'104', E'104', E'财务部', E'财务部', E'department', NULL, E'1', NULL, E'马克思钥匙', E'/1/104', E'/马克思钥匙/财务部', E'', 1, E'admin', E'2014-12-28 16:42:56', NULL, E'2014-12-28 16:42:56', E'', E'', E'', E'', 4, E'', E'', E'', E'', E'', NULL, E'', E'', NULL, E'1');
INSERT INTO mxk_organizations (id, orgcode, orgname, fullname, type, level, parentid, parentcode, parentname, codepath, namepath, description, status, createdby, createddate, modifiedby, modifieddate, address, postalcode, phone, fax, sortindex, division, country, region, locality, street, haschild, contact, email, ldapdn, instid) VALUES (E'105', E'105', E'行政部', E'行政部', E'department', NULL, E'1', NULL, E'马克思钥匙', E'/1/105', E'/马克思钥匙/行政部', E'', 1, E'admin', E'2014-12-28 16:43:08', E'admin', E'2014-12-28 16:43:08', E'', E'', E'', E'', 5, E'', E'', E'', E'', E'', NULL, E'', E'', NULL, E'1');
INSERT INTO mxk_organizations (id, orgcode, orgname, fullname, type, level, parentid, parentcode, parentname, codepath, namepath, description, status, createdby, createddate, modifiedby, modifieddate, address, postalcode, phone, fax, sortindex, division, country, region, locality, street, haschild, contact, email, ldapdn, instid) VALUES (E'106', E'106', E'分支机构', E'分支机构', E'virtual', 0, E'1', NULL, E'马克思钥匙', E'/1/106', E'/马克思钥匙/分支机构', E'', 1, NULL, NULL, NULL, NULL, E'', E'', E'', E'', 9, E'', E'', E'', E'', E'', NULL, E'', E'', NULL, E'1');
INSERT INTO mxk_organizations (id, orgcode, orgname, fullname, type, level, parentid, parentcode, parentname, codepath, namepath, description, status, createdby, createddate, modifiedby, modifieddate, address, postalcode, phone, fax, sortindex, division, country, region, locality, street, haschild, contact, email, ldapdn, instid) VALUES (E'10601', E'10601', E'北京分公司', E'北京分公司', E'virtual', 0, E'106', NULL, E'分支机构', E'/1/106/10601', E'/马克思钥匙/分支机构/北京分公司', E'', 1, E'admin', E'2014-12-28 16:53:30', NULL, E'2014-12-28 16:53:30', E'', E'', E'', E'', 11, E'', E'', E'', E'', E'', NULL, E'', E'', NULL, E'1');
INSERT INTO mxk_organizations (id, orgcode, orgname, fullname, type, level, parentid, parentcode, parentname, codepath, namepath, description, status, createdby, createddate, modifiedby, modifieddate, address, postalcode, phone, fax, sortindex, division, country, region, locality, street, haschild, contact, email, ldapdn, instid) VALUES (E'1060101', E'1060101', E'产品支持部', E'', E'virtual', 0, E'10601', NULL, E'北京分公司', E'/1/106/10601/1060101', E'/马克思钥匙/分支机构/北京分公司/产品支持部', E'', 1, E'admin', E'2014-12-28 16:53:53', NULL, E'2014-12-28 16:53:53', E'', E'', E'', E'', 11, E'', E'', E'', E'', E'', NULL, E'', E'', NULL, E'1');
INSERT INTO mxk_organizations (id, orgcode, orgname, fullname, type, level, parentid, parentcode, parentname, codepath, namepath, description, status, createdby, createddate, modifiedby, modifieddate, address, postalcode, phone, fax, sortindex, division, country, region, locality, street, haschild, contact, email, ldapdn, instid) VALUES (E'1060102', E'1060102', E'项目服务部', E'项目服务部', E'virtual', 0, E'10601', NULL, E'北京分公司', E'/1/106/10601/1060102', E'/马克思钥匙/分支机构/北京分公司/项目服务部', E'', 1, E'admin', E'2014-12-28 16:54:10', NULL, E'2014-12-28 16:54:10', E'', E'', E'', E'', 2, E'', E'', E'', E'', E'', NULL, E'', E'', NULL, E'1');
INSERT INTO mxk_organizations (id, orgcode, orgname, fullname, type, level, parentid, parentcode, parentname, codepath, namepath, description, status, createdby, createddate, modifiedby, modifieddate, address, postalcode, phone, fax, sortindex, division, country, region, locality, street, haschild, contact, email, ldapdn, instid) VALUES (E'10602', E'10602', E'上海分公司', E'上海分公司', E'virtual', 0, E'106', NULL, E'分支机构', E'/1/106/10602', E'/马克思钥匙/分支机构/上海分公司', E'', 1, NULL, E'2014-12-28 16:41:30', NULL, E'2014-12-28 16:41:30', E'', E'', E'', E'', 2, E'', E'', E'', E'', E'', NULL, E'', E'', NULL, E'1');
INSERT INTO mxk_organizations (id, orgcode, orgname, fullname, type, level, parentid, parentcode, parentname, codepath, namepath, description, status, createdby, createddate, modifiedby, modifieddate, address, postalcode, phone, fax, sortindex, division, country, region, locality, street, haschild, contact, email, ldapdn, instid) VALUES (E'10603', E'10603', E'深圳分公司', E'深圳分公司', E'virtual', 0, E'106', NULL, E'分支机构', E'/1/106/10603', E'/马克思钥匙/分支机构/深圳分公司', E'', 1, NULL, E'2014-12-28 16:41:30', NULL, E'2014-12-28 16:41:30', E'', E'', E'', E'', 3, E'', E'', E'', E'', E'', NULL, E'', E'', NULL, E'1');
INSERT INTO mxk_organizations (id, orgcode, orgname, fullname, type, level, parentid, parentcode, parentname, codepath, namepath, description, status, createdby, createddate, modifiedby, modifieddate, address, postalcode, phone, fax, sortindex, division, country, region, locality, street, haschild, contact, email, ldapdn, instid) VALUES (E'107', E'107', E'商务部', E'商务部', E'department', NULL, E'1', NULL, E'马克思钥匙', E'/1/107', E'/马克思钥匙/商务部', E'', 1, E'admin', E'2015-06-11 14:08:04', NULL, E'2015-06-11 14:08:04', E'', E'', E'', E'', 7, E'', E'', E'', E'', E'', NULL, E'', E'', NULL, E'1');
INSERT INTO mxk_organizations (id, orgcode, orgname, fullname, type, level, parentid, parentcode, parentname, codepath, namepath, description, status, createdby, createddate, modifiedby, modifieddate, address, postalcode, phone, fax, sortindex, division, country, region, locality, street, haschild, contact, email, ldapdn, instid) VALUES (E'108', E'108', E'人事部', E'人力资源管理部', E'department', NULL, E'1', NULL, E'马克思钥匙', E'/1/108', E'/马克思钥匙/人事部', E'', NULL, NULL, E'2014-12-28 16:41:30', NULL, E'2014-12-28 16:41:30', E'', E'', E'', E'', 8, E'', E'', E'', E'', E'', NULL, E'', E'', NULL, E'1');
INSERT INTO mxk_organizations (id, orgcode, orgname, fullname, type, level, parentid, parentcode, parentname, codepath, namepath, description, status, createdby, createddate, modifiedby, modifieddate, address, postalcode, phone, fax, sortindex, division, country, region, locality, street, haschild, contact, email, ldapdn, instid) VALUES (E'109', E'109', E'魏国', E'魏国', E'department', 0, E'1', NULL, E'马克思钥匙', E'/1/109', E'/马克思钥匙/魏国', E'', 1, NULL, E'2014-12-28 16:41:30', NULL, E'2014-12-28 16:41:30', E'', E'', E'', E'', 11, E'', E'魏国', E'', E'许昌', E'', NULL, E'曹操', E'', NULL, E'1');
INSERT INTO mxk_organizations (id, orgcode, orgname, fullname, type, level, parentid, parentcode, parentname, codepath, namepath, description, status, createdby, createddate, modifiedby, modifieddate, address, postalcode, phone, fax, sortindex, division, country, region, locality, street, haschild, contact, email, ldapdn, instid) VALUES (E'110', E'110', E'吴国', E'吴国', E'department', 0, E'1', NULL, E'马克思钥匙', E'/1/110', E'/马克思钥匙/吴国', E'', 1, NULL, E'2014-12-28 16:41:30', NULL, E'2014-12-28 16:41:30', E'', E'', E'', E'', 11, E'', E'吴国', E'', E'建邺', E'', NULL, E'孙权', E'', NULL, E'1');
INSERT INTO mxk_organizations (id, orgcode, orgname, fullname, type, level, parentid, parentcode, parentname, codepath, namepath, description, status, createdby, createddate, modifiedby, modifieddate, address, postalcode, phone, fax, sortindex, division, country, region, locality, street, haschild, contact, email, ldapdn, instid) VALUES (E'111', E'111', E'蜀国', E'蜀国', E'department', 0, E'1', NULL, E'马克思钥匙', E'/1/111', E'/马克思钥匙/蜀国', E'', 1, NULL, E'2014-12-28 16:41:30', NULL, E'2014-12-28 16:41:30', E'', E'', E'', E'', 11, E'', E'', E'', E'', E'', NULL, E'', E'', NULL, E'1');
INSERT INTO mxk_organizations (id, orgcode, orgname, fullname, type, level, parentid, parentcode, parentname, codepath, namepath, description, status, createdby, createddate, modifiedby, modifieddate, address, postalcode, phone, fax, sortindex, division, country, region, locality, street, haschild, contact, email, ldapdn, instid) VALUES (E'793231704339775488', E'476362842', E'商务部', NULL, E'department', 0, E'1', NULL, E'马克思钥匙', NULL, NULL, E'dingtalk', 1, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 33, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, E'1');
INSERT INTO mxk_organizations (id, orgcode, orgname, fullname, type, level, parentid, parentcode, parentname, codepath, namepath, description, status, createdby, createddate, modifiedby, modifieddate, address, postalcode, phone, fax, sortindex, division, country, region, locality, street, haschild, contact, email, ldapdn, instid) VALUES (E'793231704931172352', E'487391023', E'华东区', NULL, E'department', 0, E'1', NULL, E'马克思钥匙', NULL, NULL, E'dingtalk', 1, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 33, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, E'1');
INSERT INTO mxk_organizations (id, orgcode, orgname, fullname, type, level, parentid, parentcode, parentname, codepath, namepath, description, status, createdby, createddate, modifiedby, modifieddate, address, postalcode, phone, fax, sortindex, division, country, region, locality, street, haschild, contact, email, ldapdn, instid) VALUES (E'793231705073778688', E'487428038', E'华北区', NULL, E'department', 0, E'1', NULL, E'马克思钥匙', NULL, NULL, E'dingtalk', 1, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 33, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, E'1');
INSERT INTO mxk_organizations (id, orgcode, orgname, fullname, type, level, parentid, parentcode, parentname, codepath, namepath, description, status, createdby, createddate, modifiedby, modifieddate, address, postalcode, phone, fax, sortindex, division, country, region, locality, street, haschild, contact, email, ldapdn, instid) VALUES (E'793231705249939456', E'487530068', E'华南区', NULL, E'department', 0, E'1', NULL, E'马克思钥匙', E'/793231705249939456/', E'/华南区/', E'dingtalk', 1, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 33, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, E'1');
INSERT INTO mxk_organizations (id, orgcode, orgname, fullname, type, level, parentid, parentcode, parentname, codepath, namepath, description, status, createdby, createddate, modifiedby, modifieddate, address, postalcode, phone, fax, sortindex, division, country, region, locality, street, haschild, contact, email, ldapdn, instid) VALUES (E'793231711801442304', E'487185040', E'河北分公司', NULL, E'department', 0, E'793231705073778688', NULL, E'华北区', NULL, NULL, E'dingtalk', 1, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 33, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, E'1');
INSERT INTO mxk_organizations (id, orgcode, orgname, fullname, type, level, parentid, parentcode, parentname, codepath, namepath, description, status, createdby, createddate, modifiedby, modifieddate, address, postalcode, phone, fax, sortindex, division, country, region, locality, street, haschild, contact, email, ldapdn, instid) VALUES (E'793231711931465728', E'487287050', E'济南分公司', NULL, E'department', 0, E'793231705073778688', NULL, E'华北区', NULL, NULL, E'dingtalk', 1, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 33, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, E'1');
INSERT INTO mxk_organizations (id, orgcode, orgname, fullname, type, level, parentid, parentcode, parentname, codepath, namepath, description, status, createdby, createddate, modifiedby, modifieddate, address, postalcode, phone, fax, sortindex, division, country, region, locality, street, haschild, contact, email, ldapdn, instid) VALUES (E'793231712065683456', E'487541049', E'北京分公司', NULL, E'department', 0, E'793231705073778688', NULL, E'华北区', NULL, NULL, E'dingtalk', 1, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 33, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, E'1');
INSERT INTO mxk_organizations (id, orgcode, orgname, fullname, type, level, parentid, parentcode, parentname, codepath, namepath, description, status, createdby, createddate, modifiedby, modifieddate, address, postalcode, phone, fax, sortindex, division, country, region, locality, street, haschild, contact, email, ldapdn, instid) VALUES (E'793231712132792320', E'487546049', E'太原分公司', NULL, E'department', 0, E'793231705073778688', NULL, E'华北区', NULL, NULL, E'dingtalk', 1, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 33, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, E'1');
INSERT INTO mxk_organizations (id, orgcode, orgname, fullname, type, level, parentid, parentcode, parentname, codepath, namepath, description, status, createdby, createddate, modifiedby, modifieddate, address, postalcode, phone, fax, sortindex, division, country, region, locality, street, haschild, contact, email, ldapdn, instid) VALUES (E'793231713248477184', E'487430049', E'广州分公司', NULL, E'department', 0, E'793231705249939456', NULL, E'华南区', E'/793231705249939456/793231713248477184/', E'/华南区/广州分公司/', E'dingtalk', 1, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 33, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, E'1');
INSERT INTO mxk_organizations (id, orgcode, orgname, fullname, type, level, parentid, parentcode, parentname, codepath, namepath, description, status, createdby, createddate, modifiedby, modifieddate, address, postalcode, phone, fax, sortindex, division, country, region, locality, street, haschild, contact, email, ldapdn, instid) VALUES (E'793231713315586048', E'487496037', E'南宁分公司', NULL, E'department', 0, E'793231705249939456', NULL, E'华南区', E'/793231705249939456/793231713315586048/', E'/华南区/南宁分公司/', E'dingtalk', 1, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 33, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, E'1');
INSERT INTO mxk_organizations (id, orgcode, orgname, fullname, type, level, parentid, parentcode, parentname, codepath, namepath, description, status, createdby, createddate, modifiedby, modifieddate, address, postalcode, phone, fax, sortindex, division, country, region, locality, street, haschild, contact, email, ldapdn, instid) VALUES (E'793231713474969600', E'487602077', E'福建分公司', NULL, E'department', 0, E'793231705249939456', NULL, E'华南区', E'/793231705249939456/793231713474969600/', E'/华南区/福建分公司/', E'dingtalk', 1, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 33, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, E'1');
INSERT INTO mxk_organizations (id, orgcode, orgname, fullname, type, level, parentid, parentcode, parentname, codepath, namepath, description, status, createdby, createddate, modifiedby, modifieddate, address, postalcode, phone, fax, sortindex, division, country, region, locality, street, haschild, contact, email, ldapdn, instid) VALUES (E'793231716385816576', E'486884107', E'海定办事处', NULL, E'department', 0, E'793231712065683456', NULL, E'北京分公司', NULL, NULL, E'dingtalk', 1, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 33, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, E'1');
INSERT INTO mxk_organizations (id, orgcode, orgname, fullname, type, level, parentid, parentcode, parentname, codepath, namepath, description, status, createdby, createddate, modifiedby, modifieddate, address, postalcode, phone, fax, sortindex, division, country, region, locality, street, haschild, contact, email, ldapdn, instid) VALUES (E'793231716541005824', E'487462032', E'石景山办事处', NULL, E'department', 0, E'793231712065683456', NULL, E'北京分公司', NULL, NULL, E'dingtalk', 1, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 33, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, E'1');
INSERT INTO mxk_organizations (id, orgcode, orgname, fullname, type, level, parentid, parentcode, parentname, codepath, namepath, description, status, createdby, createddate, modifiedby, modifieddate, address, postalcode, phone, fax, sortindex, division, country, region, locality, street, haschild, contact, email, ldapdn, instid) VALUES (E'793231716650057728', E'487586041', E'朝阳办事处', NULL, E'department', 0, E'793231712065683456', NULL, E'北京分公司', NULL, NULL, E'dingtalk', 1, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 33, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, E'1');
INSERT INTO mxk_organizations (id, orgcode, orgname, fullname, type, level, parentid, parentcode, parentname, codepath, namepath, description, status, createdby, createddate, modifiedby, modifieddate, address, postalcode, phone, fax, sortindex, division, country, region, locality, street, haschild, contact, email, ldapdn, instid) VALUES (E'984026174621483008', NULL, E'浙江分公司', E'浙江分公司', E'department', 0, E'106', NULL, E'分支机构', NULL, NULL, NULL, 1, NULL, E'2024-05-04 06:49:47', NULL, NULL, NULL, NULL, NULL, NULL, 11, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'04d07d92-c223-4854-8932-6a72ffd49665', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'7452d560-0bc0-4bda-b2eb-d9dc7432d973', E'8aca327e-033e-4867-b991-6fb9303f5aaa', NULL, E'2020-07-19 09:59:14', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'05a3d552-f4aa-4dc3-9619-61a65d98d966', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'7452d560-0bc0-4bda-b2eb-d9dc7432d973', E'75b21762-08c9-4e37-bf62-5e762339e159', NULL, E'2020-07-19 09:59:14', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'06a499e0-f2df-43b4-b065-9670e2d4bcdb', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'e238e0d1-b3db-472f-b0bf-38d889ba2df3', NULL, E'2020-07-19 09:59:21', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'070e6347-eeb4-4fea-8be6-f600d11808f7', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'f2f7f1bb-245c-4f22-bf8e-9d9f6e30b699', E'1824404a-5979-40f3-9d0e-2c1196209afb', NULL, E'2020-07-19 10:01:59', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'07284c3a-8d3c-4c18-a8c0-85170e49f48e', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'7452d560-0bc0-4bda-b2eb-d9dc7432d973', E'80a7a954-7dfa-454b-b4ed-3f52feeef8a3', NULL, E'2020-07-19 09:59:14', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'08711743-1c7f-49d6-910f-47f47d9b8b26', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'70b2522b-e943-4d8e-860f-7c5ae7d9569f', NULL, E'2020-07-19 00:55:45', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'0a9309eb-6a7d-4698-b3e3-2fb2eeebba24', E'maxkey_mgt', E'dff01736-64e9-42ef-92bd-cda2ca91044f', E'c4ff1146-e1f3-4219-8191-d5010b36c153', NULL, E'2020-05-10 21:43:37', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'0afa9824-690d-4985-a0a9-aab1147812e9', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'8a1ba67d-29a3-472d-9d8c-beffb14c48ce', E'1be7c248-6682-44ff-b688-4310d2e9be8a', NULL, E'2020-07-19 10:00:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'0dcadea9-4902-48cc-a78f-ae30979f0b25', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'e0d12156-63f4-4142-9dff-91342149262b', E'27e7471a-ba2c-4dde-9228-c804f096d19d', NULL, E'2020-07-19 10:01:40', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'0e1fe744-c90d-4866-8bf0-f49945e69226', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'dff01736-64e9-42ef-92bd-cda2ca91044f', E'fddc2287-0628-489f-807d-7bcb49285632', NULL, E'2020-07-19 10:01:26', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'0f3f8c74-e552-4585-8b75-69f1d8d30b88', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'c9991957-2579-4529-86d6-ea386e37c27a', NULL, E'2020-07-19 09:59:21', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'0fc23ab1-359b-4241-a234-d86f76a4953e', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'ce609834-e01c-4336-af95-373cf08447aa', E'ab715383-8fa5-4225-b0a2-ab01991b98e7', NULL, E'2020-07-19 10:00:54', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'1046922d-3b6a-480c-b38b-f4b16a7f19e3', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'8a1ba67d-29a3-472d-9d8c-beffb14c48ce', E'c9991957-2579-4529-86d6-ea386e37c27a', NULL, E'2020-07-19 10:00:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'1200a9e7-2fca-4826-a37d-f64a92dc5935', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'7452d560-0bc0-4bda-b2eb-d9dc7432d973', E'fddc2287-0628-489f-807d-7bcb49285632', NULL, E'2020-07-19 09:59:14', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'12dc288f-94a5-4d61-aee9-5de9808ee97a', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'fcbc7a33-ad60-4d63-9b14-9b41120bdb49', NULL, E'2020-07-19 00:55:45', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'137eff18-455f-42d3-a274-e3118b1e19a0', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'7452d560-0bc0-4bda-b2eb-d9dc7432d973', E'8c3da816-882c-466d-aec2-92a02cbbe5d7', NULL, E'2020-07-19 09:59:14', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'13aa17e3-4c6c-4074-8c4b-40687ab09f1d', E'maxkey_mgt', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'c4ff1146-e1f3-4219-8191-d5010b36c153', NULL, E'2020-04-30 12:16:07', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'13ef864f-8612-497f-8d52-91a2715bb6fa', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'ab715383-8fa5-4225-b0a2-ab01991b98e7', NULL, E'2020-07-19 09:59:21', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'14c893e2-c636-4a82-8b38-91b83fe3dd4d', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'e0d12156-63f4-4142-9dff-91342149262b', E'18a82e89-56f7-4538-975f-7de500e5e15e', NULL, E'2020-07-19 10:01:40', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'157b8824-2ea4-447b-962a-39313aca6335', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'7452d560-0bc0-4bda-b2eb-d9dc7432d973', E'f44a0273-ba7c-4301-b84f-c9ba9f199cda', NULL, E'2020-07-19 09:59:14', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'1705e097-39f9-48bd-b0f8-7f6c5af51ecb', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'8a1ba67d-29a3-472d-9d8c-beffb14c48ce', E'8aca327e-033e-4867-b991-6fb9303f5aaa', NULL, E'2020-07-19 10:00:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'17cb017e-621f-40f6-a20d-ff0c02700378', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'8a1ba67d-29a3-472d-9d8c-beffb14c48ce', E'18a82e89-56f7-4538-975f-7de500e5e15e', NULL, E'2020-07-19 10:00:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'18e6f20c-c436-48ed-b4e0-1e63dbd1b15e', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'7452d560-0bc0-4bda-b2eb-d9dc7432d973', E'463da0ad-55f2-486a-a01f-66b44a2ba18d', NULL, E'2020-07-19 09:59:14', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'1f4b1b48-8271-44bc-9b9f-4cfe65f1a929', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'359520ca-6699-45cd-b010-b288c9f1b835', E'18a82e89-56f7-4538-975f-7de500e5e15e', NULL, E'2021-04-17 16:49:43', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'22a8e855-e5a9-44cb-baa3-7a2e6f502dda', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'7452d560-0bc0-4bda-b2eb-d9dc7432d973', E'f8091914-e67c-4377-a68e-0798b31f33bb', NULL, E'2020-07-19 09:59:14', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'28902309-cf1d-4ed5-a922-9a20c3e11a27', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'27e7471a-ba2c-4dde-9228-c804f096d19d', NULL, E'2020-07-19 00:55:45', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'2954902d-f257-4af6-8916-eff031e553ad', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'872de4f0-8ae3-4e16-b8ef-2e87058045b7', E'c9991957-2579-4529-86d6-ea386e37c27a', NULL, E'2020-07-19 10:00:19', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'2bfbbf05-11f5-4be0-a24b-c76628b85a9f', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'e0d12156-63f4-4142-9dff-91342149262b', E'80a7a954-7dfa-454b-b4ed-3f52feeef8a3', NULL, E'2020-07-19 10:01:40', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'2f052c56-4b2c-4354-bbd0-5a14d54aa7ff', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'ce609834-e01c-4336-af95-373cf08447aa', E'f44a0273-ba7c-4301-b84f-c9ba9f199cda', NULL, E'2020-07-19 10:00:54', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'2f08ce04-6a6c-49a6-a986-41fb8f779d61', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'dff01736-64e9-42ef-92bd-cda2ca91044f', E'913f7a47-8cdc-4f5f-bc99-1f580f86a63e', NULL, E'2020-07-19 10:01:26', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'318c5d38-99fe-40d7-bb16-e76d21f9a00c', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'1be7c248-6682-44ff-b688-4310d2e9be8a', NULL, E'2020-07-19 09:59:21', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'3195763c-9b93-4cfe-8862-c7414eb704ac', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'e0d12156-63f4-4142-9dff-91342149262b', E'463da0ad-55f2-486a-a01f-66b44a2ba18d', NULL, E'2020-07-19 10:01:40', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'337c736a-9940-4bd5-9b69-d74e7ac05ed1', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'e238e0d1-b3db-472f-b0bf-38d889ba2df3', NULL, E'2020-07-19 00:55:45', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'33ae5951-c511-49ce-9938-9010c3700c19', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'237e3cce-7cb7-4646-bc1a-6ca941931b5c', NULL, E'2020-07-19 09:59:21', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'34b953e0-7c53-454e-acfb-4c1b68f184d4', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'8a1ba67d-29a3-472d-9d8c-beffb14c48ce', E'237e3cce-7cb7-4646-bc1a-6ca941931b5c', NULL, E'2020-07-19 10:00:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'3506fb97-7ec5-46ce-bf4e-399848d90e85', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'e0d12156-63f4-4142-9dff-91342149262b', E'913f7a47-8cdc-4f5f-bc99-1f580f86a63e', NULL, E'2020-07-19 10:01:40', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'36cd7b1a-c51c-4a2d-8f5a-8aafbb5e32b4', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'7452d560-0bc0-4bda-b2eb-d9dc7432d973', E'ab715383-8fa5-4225-b0a2-ab01991b98e7', NULL, E'2020-07-19 09:59:14', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'399dac1d-e20c-4e20-8e0c-d9e0b134a79b', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'7452d560-0bc0-4bda-b2eb-d9dc7432d973', E'c031c924-ee84-4719-843f-493409181440', NULL, E'2020-07-19 09:59:14', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'3c2c4027-5f13-4440-89c5-503a9633a46e', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'7452d560-0bc0-4bda-b2eb-d9dc7432d973', E'4d7cb056-7c3f-44b5-8be6-98a088b8d09f', NULL, E'2020-07-19 09:59:14', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'3c673b19-b8a6-4243-9bf6-8d7241d5519d', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'6536e3f3-284d-4156-807f-bdc7caf46c64', NULL, E'2020-07-19 09:59:21', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'3d2517be-dd21-452c-a12f-6fade90c5b1d', E'maxkey_mgt', E'8a1ba67d-29a3-472d-9d8c-beffb14c48ce', E'222', NULL, E'2020-04-29 20:47:59', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'3d2af169-1998-4922-947d-ccc1be338a67', E'maxkey_mgt', E'8a1ba67d-29a3-472d-9d8c-beffb14c48ce', E'222', NULL, E'2020-06-06 20:10:33', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'3d8d9962-33c1-46c5-bb31-cde31d12117d', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'0f92f830-8a3c-4e0c-b40a-0645bd96cb3c', NULL, E'2020-07-19 00:55:45', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'42c4ca8a-b158-44a8-a7d7-f06d709791a0', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'1824404a-5979-40f3-9d0e-2c1196209afb', NULL, E'2020-07-19 09:59:21', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'43131a45-ffb3-4ac2-8877-18a6d236e0d9', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'e0d12156-63f4-4142-9dff-91342149262b', E'32ed9486-f002-4ee9-8d91-97b6b5a3bada', NULL, E'2020-07-19 10:01:40', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'43d361e4-aaaa-4851-b59e-6a2abf8f666a', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'8a1ba67d-29a3-472d-9d8c-beffb14c48ce', E'0f92f830-8a3c-4e0c-b40a-0645bd96cb3c', NULL, E'2020-07-19 10:00:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'43e8eb12-36fe-4011-a1da-5e20a42f2ebc', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'e0d12156-63f4-4142-9dff-91342149262b', E'04ee2f33-3ced-4c23-992c-5c85b03dbc20', NULL, E'2020-07-19 10:01:40', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'44aaee40-5788-4e98-9499-7ba34575ad5b', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'80a7a954-7dfa-454b-b4ed-3f52feeef8a3', NULL, E'2020-07-19 09:59:21', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'45e669c5-1cdc-4187-994a-262225da349d', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'f44a0273-ba7c-4301-b84f-c9ba9f199cda', NULL, E'2020-07-19 09:59:21', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'46242217-3cd2-49a5-86f4-d8398a540a2d', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'ce609834-e01c-4336-af95-373cf08447aa', E'4d7cb056-7c3f-44b5-8be6-98a088b8d09f', NULL, E'2020-07-19 10:00:54', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'463246d7-56ab-4afd-8b81-d568467081bc', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'8a1ba67d-29a3-472d-9d8c-beffb14c48ce', E'6536e3f3-284d-4156-807f-bdc7caf46c64', NULL, E'2020-07-19 10:00:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'47213f25-32fe-405a-9502-d83f54880267', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'0f92f830-8a3c-4e0c-b40a-0645bd96cb3c', NULL, E'2020-07-19 09:59:21', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'4876e478-ce0c-42b6-9b0b-97e3fe790a2b', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'8a1ba67d-29a3-472d-9d8c-beffb14c48ce', E'3b795490-4a46-4122-b656-861f871725c3', NULL, E'2020-07-19 10:00:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'4893c438-34f5-4159-bb94-c23b51729028', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'e0d12156-63f4-4142-9dff-91342149262b', E'fddc2287-0628-489f-807d-7bcb49285632', NULL, E'2020-07-19 10:01:40', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'4b265f3f-1cd2-4741-9087-1dac66452925', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'8a1ba67d-29a3-472d-9d8c-beffb14c48ce', E'231c6a4b-a903-47ed-8110-4664371e326e', NULL, E'2020-07-19 10:00:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'4e7c8663-cb1d-4640-88af-da483c4a0b8a', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'6536e3f3-284d-4156-807f-bdc7caf46c64', NULL, E'2020-07-19 00:55:45', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'4f39687c-67c2-4f0d-92dc-dcab1a7125f4', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'75b21762-08c9-4e37-bf62-5e762339e159', NULL, E'2020-07-19 09:59:21', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'51c7d260-2807-49d8-9e2c-2b547aaf0ceb', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'7452d560-0bc0-4bda-b2eb-d9dc7432d973', E'18a82e89-56f7-4538-975f-7de500e5e15e', NULL, E'2020-07-19 09:59:14', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'536a34db-eda9-4895-9d0e-87b01450e439', E'maxkey_mgt', E'8a1ba67d-29a3-472d-9d8c-beffb14c48ce', E'c4ff1146-e1f3-4219-8191-d5010b36c153', NULL, E'2020-06-06 20:10:33', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'53f728eb-c37b-4ee0-90b6-fea43da5c927', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'e0d12156-63f4-4142-9dff-91342149262b', E'8c3da816-882c-466d-aec2-92a02cbbe5d7', NULL, E'2020-07-19 10:01:40', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'554385bb-c110-4460-8a41-25f989d21d6d', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'f44a0273-ba7c-4301-b84f-c9ba9f199cda', NULL, E'2020-07-19 00:55:45', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'580842189307772929', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'359520ca-6699-45cd-b010-b288c9f1b835', E'04ee2f33-3ced-4c23-992c-5c85b03dbc20', NULL, E'2021-04-17 17:00:35', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'580842189307772930', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'359520ca-6699-45cd-b010-b288c9f1b835', E'18a82e89-56f7-4538-975f-7de500e5e15e', NULL, E'2021-04-17 17:00:35', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'580842189307772931', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'359520ca-6699-45cd-b010-b288c9f1b835', E'8c3da816-882c-466d-aec2-92a02cbbe5d7', NULL, E'2021-04-17 17:00:35', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'580842189307772932', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'359520ca-6699-45cd-b010-b288c9f1b835', E'3b795490-4a46-4122-b656-861f871725c3', NULL, E'2021-04-17 17:00:35', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'580842189307772933', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'359520ca-6699-45cd-b010-b288c9f1b835', E'e238e0d1-b3db-472f-b0bf-38d889ba2df3', NULL, E'2021-04-17 17:00:35', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'580842189307772934', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'359520ca-6699-45cd-b010-b288c9f1b835', E'70b2522b-e943-4d8e-860f-7c5ae7d9569f', NULL, E'2021-04-17 17:00:35', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'590cad70-166a-49be-8ade-8f42293ac90a', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'7829374f-4503-4738-b661-72c2efb6d640', NULL, E'2020-07-19 00:55:45', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'591c0e41-43c6-4626-bb56-64e276228b38', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'dff01736-64e9-42ef-92bd-cda2ca91044f', E'4d7cb056-7c3f-44b5-8be6-98a088b8d09f', NULL, E'2020-07-19 10:01:26', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'5a5aff58-10c4-4ba2-9969-86cc9e9ec3af', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'8a1ba67d-29a3-472d-9d8c-beffb14c48ce', E'f44a0273-ba7c-4301-b84f-c9ba9f199cda', NULL, E'2020-07-19 10:00:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'5af6baf9-4038-4cd2-82b9-d959610d1014', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'ab6c11c9-7aa8-4428-beb2-f1ab77e8796e', NULL, E'2020-07-19 09:59:21', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'5b4928f8-9397-42ef-840c-20174345ff0c', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'237e3cce-7cb7-4646-bc1a-6ca941931b5c', NULL, E'2020-07-19 00:55:45', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'5c1d71b4-d80d-4423-bfa3-e812b23f98e8', E'maxkey_mgt', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'222', NULL, E'2020-04-29 20:17:41', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'5c751216-90dc-4c0d-8066-68cc30bd392c', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'fddc2287-0628-489f-807d-7bcb49285632', NULL, E'2020-07-19 09:59:21', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'5e156ff6-2d42-46bf-bb75-2610543fd95a', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'872de4f0-8ae3-4e16-b8ef-2e87058045b7', E'f8091914-e67c-4377-a68e-0798b31f33bb', NULL, E'2020-07-19 10:00:19', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'5f4ea407-23b1-43c3-bf56-1c80fc6e048c', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'8a1ba67d-29a3-472d-9d8c-beffb14c48ce', E'fcbc7a33-ad60-4d63-9b14-9b41120bdb49', NULL, E'2020-07-19 10:00:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'612800686001750045', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'c031c924-ee84-4719-843f-493409181440', NULL, E'2021-07-14 21:32:14', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'612800686001750046', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'f8091914-e67c-4377-a68e-0798b31f33bb', NULL, E'2021-07-14 21:32:14', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'612800686001750047', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'c9991957-2579-4529-86d6-ea386e37c27a', NULL, E'2021-07-14 21:32:14', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245842115362817', E'622227747938373638', E'622227747942568001', E'04ee2f33-3ced-4c23-992c-5c85b03dbc20', NULL, E'2021-08-09 23:03:55', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245842115362818', E'622227747938373638', E'622227747942568001', E'18a82e89-56f7-4538-975f-7de500e5e15e', NULL, E'2021-08-09 23:03:55', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245842115362819', E'622227747938373638', E'622227747942568001', E'8c3da816-882c-466d-aec2-92a02cbbe5d7', NULL, E'2021-08-09 23:03:55', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245842115362820', E'622227747938373638', E'622227747942568001', E'3b795490-4a46-4122-b656-861f871725c3', NULL, E'2021-08-09 23:03:55', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245842115362821', E'622227747938373638', E'622227747942568001', E'e238e0d1-b3db-472f-b0bf-38d889ba2df3', NULL, E'2021-08-09 23:03:55', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245842115362822', E'622227747938373638', E'622227747942568001', E'70b2522b-e943-4d8e-860f-7c5ae7d9569f', NULL, E'2021-08-09 23:03:55', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245842115362823', E'622227747938373638', E'622227747942568001', E'27e7471a-ba2c-4dde-9228-c804f096d19d', NULL, E'2021-08-09 23:03:55', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245842115362824', E'622227747938373638', E'622227747942568001', E'8aca327e-033e-4867-b991-6fb9303f5aaa', NULL, E'2021-08-09 23:03:55', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245842115362825', E'622227747938373638', E'622227747942568001', E'a2b1968e-78ab-46f6-96b2-7b6bab334218', NULL, E'2021-08-09 23:03:55', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245842115362826', E'622227747938373638', E'622227747942568001', E'80a7a954-7dfa-454b-b4ed-3f52feeef8a3', NULL, E'2021-08-09 23:03:55', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245842115362827', E'622227747938373638', E'622227747942568001', E'463da0ad-55f2-486a-a01f-66b44a2ba18d', NULL, E'2021-08-09 23:03:55', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245842115362828', E'622227747938373638', E'622227747942568001', E'0f92f830-8a3c-4e0c-b40a-0645bd96cb3c', NULL, E'2021-08-09 23:03:55', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245842115362829', E'622227747938373638', E'622227747942568001', E'231c6a4b-a903-47ed-8110-4664371e326e', NULL, E'2021-08-09 23:03:55', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245842115362830', E'622227747938373638', E'622227747942568001', E'7829374f-4503-4738-b661-72c2efb6d640', NULL, E'2021-08-09 23:03:55', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245842115362831', E'622227747938373638', E'622227747942568001', E'ab6c11c9-7aa8-4428-beb2-f1ab77e8796e', NULL, E'2021-08-09 23:03:55', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245842115362832', E'622227747938373638', E'622227747942568001', E'1824404a-5979-40f3-9d0e-2c1196209afb', NULL, E'2021-08-09 23:03:55', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245842115362833', E'622227747938373638', E'622227747942568001', E'6536e3f3-284d-4156-807f-bdc7caf46c64', NULL, E'2021-08-09 23:03:55', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245842115362834', E'622227747938373638', E'622227747942568001', E'4de2475d-2a31-4178-af34-12eb39248d1d', NULL, E'2021-08-09 23:03:55', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245842115362835', E'622227747938373638', E'622227747942568001', E'75b21762-08c9-4e37-bf62-5e762339e159', NULL, E'2021-08-09 23:03:55', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245842115362836', E'622227747938373638', E'622227747942568001', E'32ed9486-f002-4ee9-8d91-97b6b5a3bada', NULL, E'2021-08-09 23:03:55', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245842115362837', E'622227747938373638', E'622227747942568001', E'4d7cb056-7c3f-44b5-8be6-98a088b8d09f', NULL, E'2021-08-09 23:03:55', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245842115362838', E'622227747938373638', E'622227747942568001', E'1be7c248-6682-44ff-b688-4310d2e9be8a', NULL, E'2021-08-09 23:03:55', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245842115362839', E'622227747938373638', E'622227747942568001', E'237e3cce-7cb7-4646-bc1a-6ca941931b5c', NULL, E'2021-08-09 23:03:55', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245842115362840', E'622227747938373638', E'622227747942568001', E'f44a0273-ba7c-4301-b84f-c9ba9f199cda', NULL, E'2021-08-09 23:03:55', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245842115362841', E'622227747938373638', E'622227747942568001', E'fcbc7a33-ad60-4d63-9b14-9b41120bdb49', NULL, E'2021-08-09 23:03:55', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245842115362842', E'622227747938373638', E'622227747942568001', E'ab715383-8fa5-4225-b0a2-ab01991b98e7', NULL, E'2021-08-09 23:03:55', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245842115362843', E'622227747938373638', E'622227747942568001', E'913f7a47-8cdc-4f5f-bc99-1f580f86a63e', NULL, E'2021-08-09 23:03:55', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245842115362844', E'622227747938373638', E'622227747942568001', E'fddc2287-0628-489f-807d-7bcb49285632', NULL, E'2021-08-09 23:03:55', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245842115362845', E'622227747938373638', E'622227747942568001', E'c031c924-ee84-4719-843f-493409181440', NULL, E'2021-08-09 23:03:55', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245842115362846', E'622227747938373638', E'622227747942568001', E'f8091914-e67c-4377-a68e-0798b31f33bb', NULL, E'2021-08-09 23:03:55', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245842115362847', E'622227747938373638', E'622227747942568001', E'c9991957-2579-4529-86d6-ea386e37c27a', NULL, E'2021-08-09 23:03:55', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245895211057153', E'622227747938373638', E'622227747942568004', E'4d7cb056-7c3f-44b5-8be6-98a088b8d09f', NULL, E'2021-08-09 23:04:07', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245895211057154', E'622227747938373638', E'622227747942568004', E'1be7c248-6682-44ff-b688-4310d2e9be8a', NULL, E'2021-08-09 23:04:07', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245895211057155', E'622227747938373638', E'622227747942568004', E'237e3cce-7cb7-4646-bc1a-6ca941931b5c', NULL, E'2021-08-09 23:04:07', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245895211057156', E'622227747938373638', E'622227747942568004', E'f44a0273-ba7c-4301-b84f-c9ba9f199cda', NULL, E'2021-08-09 23:04:07', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245895211057157', E'622227747938373638', E'622227747942568004', E'fcbc7a33-ad60-4d63-9b14-9b41120bdb49', NULL, E'2021-08-09 23:04:07', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245895211057158', E'622227747938373638', E'622227747942568004', E'ab715383-8fa5-4225-b0a2-ab01991b98e7', NULL, E'2021-08-09 23:04:07', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245895211057159', E'622227747938373638', E'622227747942568004', E'913f7a47-8cdc-4f5f-bc99-1f580f86a63e', NULL, E'2021-08-09 23:04:07', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245895211057160', E'622227747938373638', E'622227747942568004', E'fddc2287-0628-489f-807d-7bcb49285632', NULL, E'2021-08-09 23:04:07', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245895211057161', E'622227747938373638', E'622227747942568004', E'c031c924-ee84-4719-843f-493409181440', NULL, E'2021-08-09 23:04:07', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245895211057162', E'622227747938373638', E'622227747942568004', E'f8091914-e67c-4377-a68e-0798b31f33bb', NULL, E'2021-08-09 23:04:07', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245895211057163', E'622227747938373638', E'622227747942568004', E'c9991957-2579-4529-86d6-ea386e37c27a', NULL, E'2021-08-09 23:04:07', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245939515490305', E'622227747938373638', E'622227747942568006', E'4d7cb056-7c3f-44b5-8be6-98a088b8d09f', NULL, E'2021-08-09 23:04:18', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245939515490306', E'622227747938373638', E'622227747942568006', E'1be7c248-6682-44ff-b688-4310d2e9be8a', NULL, E'2021-08-09 23:04:18', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245939515490307', E'622227747938373638', E'622227747942568006', E'237e3cce-7cb7-4646-bc1a-6ca941931b5c', NULL, E'2021-08-09 23:04:18', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245939515490308', E'622227747938373638', E'622227747942568006', E'f44a0273-ba7c-4301-b84f-c9ba9f199cda', NULL, E'2021-08-09 23:04:18', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245939515490309', E'622227747938373638', E'622227747942568006', E'fcbc7a33-ad60-4d63-9b14-9b41120bdb49', NULL, E'2021-08-09 23:04:18', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245939515490310', E'622227747938373638', E'622227747942568006', E'ab715383-8fa5-4225-b0a2-ab01991b98e7', NULL, E'2021-08-09 23:04:18', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245939515490311', E'622227747938373638', E'622227747942568006', E'913f7a47-8cdc-4f5f-bc99-1f580f86a63e', NULL, E'2021-08-09 23:04:18', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245939515490312', E'622227747938373638', E'622227747942568006', E'fddc2287-0628-489f-807d-7bcb49285632', NULL, E'2021-08-09 23:04:18', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245982607769601', E'622227747938373638', E'622227747942568009', E'0f92f830-8a3c-4e0c-b40a-0645bd96cb3c', NULL, E'2021-08-09 23:04:28', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245982607769602', E'622227747938373638', E'622227747942568009', E'231c6a4b-a903-47ed-8110-4664371e326e', NULL, E'2021-08-09 23:04:28', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245982607769603', E'622227747938373638', E'622227747942568009', E'7829374f-4503-4738-b661-72c2efb6d640', NULL, E'2021-08-09 23:04:28', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245982607769604', E'622227747938373638', E'622227747942568009', E'ab6c11c9-7aa8-4428-beb2-f1ab77e8796e', NULL, E'2021-08-09 23:04:28', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'622245982607769605', E'622227747938373638', E'622227747942568009', E'1824404a-5979-40f3-9d0e-2c1196209afb', NULL, E'2021-08-09 23:04:28', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'65b5e753-0e4c-4552-9ddb-0b3ededb0e95', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'7452d560-0bc0-4bda-b2eb-d9dc7432d973', E'913f7a47-8cdc-4f5f-bc99-1f580f86a63e', NULL, E'2020-07-19 09:59:14', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'670caacf-b612-40e3-bbf4-792d325d679d', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'463da0ad-55f2-486a-a01f-66b44a2ba18d', NULL, E'2020-07-19 09:59:21', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'673de18e-1883-445a-ba52-dc0efae93916', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'8a1ba67d-29a3-472d-9d8c-beffb14c48ce', E'913f7a47-8cdc-4f5f-bc99-1f580f86a63e', NULL, E'2020-07-19 10:00:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'67f02892-8bd3-498a-82ac-d31a05122291', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'18a82e89-56f7-4538-975f-7de500e5e15e', NULL, E'2020-07-19 09:59:21', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'682d2407-6588-4714-83a6-e4db5b77e6e5', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'75b21762-08c9-4e37-bf62-5e762339e159', NULL, E'2020-07-19 00:55:45', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'683367357342547969', E'622227747938373638', E'622227747942568005', NULL, NULL, E'2022-01-25 14:58:59', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'683367357342547970', E'622227747938373638', E'622227747942568005', NULL, NULL, E'2022-01-25 14:58:59', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'683367357342547971', E'622227747938373638', E'622227747942568005', NULL, NULL, E'2022-01-25 14:58:59', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'683370454123020297', E'622227747938373638', E'622227747942568006', E'c031c924-ee84-4719-843f-493409181440', NULL, E'2022-01-25 15:11:18', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'683370454123020298', E'622227747938373638', E'622227747942568006', E'f8091914-e67c-4377-a68e-0798b31f33bb', NULL, E'2022-01-25 15:11:18', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'683370454123020299', E'622227747938373638', E'622227747942568006', E'c9991957-2579-4529-86d6-ea386e37c27a', NULL, E'2022-01-25 15:11:18', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'683370526042750977', E'622227747938373638', E'622227747942568007', E'913f7a47-8cdc-4f5f-bc99-1f580f86a63e', NULL, E'2022-01-25 15:11:35', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'683370526042750978', E'622227747938373638', E'622227747942568007', E'fddc2287-0628-489f-807d-7bcb49285632', NULL, E'2022-01-25 15:11:35', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'683370526042750979', E'622227747938373638', E'622227747942568007', E'c031c924-ee84-4719-843f-493409181440', NULL, E'2022-01-25 15:11:35', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'683370526042750980', E'622227747938373638', E'622227747942568007', E'f8091914-e67c-4377-a68e-0798b31f33bb', NULL, E'2022-01-25 15:11:35', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'683370526042750981', E'622227747938373638', E'622227747942568007', E'c9991957-2579-4529-86d6-ea386e37c27a', NULL, E'2022-01-25 15:11:35', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'69a483ce-f9d2-426f-86d0-4f0ee219b422', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'7452d560-0bc0-4bda-b2eb-d9dc7432d973', E'fcbc7a33-ad60-4d63-9b14-9b41120bdb49', NULL, E'2020-07-19 09:59:14', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'69b429eb-da9c-431f-88cb-b93981930a9f', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'8a1ba67d-29a3-472d-9d8c-beffb14c48ce', E'4de2475d-2a31-4178-af34-12eb39248d1d', NULL, E'2020-07-19 10:00:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'6a0d4ddf-e387-4fa3-a4a1-5f6b2d1a60e8', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'4d7cb056-7c3f-44b5-8be6-98a088b8d09f', NULL, E'2020-07-19 09:59:21', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'6f60f598-05d8-4b88-884d-aa2c1c12fcfe', E'maxkey_mgt', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'b1c9395b-c045-4e0b-9b33-effa892d923d', NULL, E'2020-04-29 20:17:41', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'708074578638798848', E'622227747938373638', E'622227747942568001', E'c031c924-ee84-4719-843f-493409181440', NULL, E'2022-04-03 19:16:40', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'708074656011124736', E'622227747938373638', E'622227747942568001', E'04ee2f33-3ced-4c23-992c-5c85b03dbc20', NULL, E'2022-04-03 19:16:59', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'708074707974356992', E'622227747938373638', E'622227747942568001', E'0f92f830-8a3c-4e0c-b40a-0645bd96cb3c', NULL, E'2022-04-03 19:17:11', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'708076799287885824', E'622227747938373638', E'622227747942568001', E'913f7a47-8cdc-4f5f-bc99-1f580f86a63e', NULL, E'2022-04-03 19:25:30', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'708076976430120960', E'622227747938373638', E'622227747942568001', E'8c3da816-882c-466d-aec2-92a02cbbe5d7', NULL, E'2022-04-03 19:26:12', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'708078016063864832', E'622227747938373638', E'622227747942568001', E'ab6c11c9-7aa8-4428-beb2-f1ab77e8796e', NULL, E'2022-04-03 19:30:20', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'708078016063864833', E'622227747938373638', E'622227747942568001', E'7829374f-4503-4738-b661-72c2efb6d640', NULL, E'2022-04-03 19:30:20', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'708078156531105792', E'622227747938373638', E'622227747942568001', E'27e7471a-ba2c-4dde-9228-c804f096d19d', NULL, E'2022-04-03 19:30:53', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'708078330724745216', E'622227747938373638', E'622227747942568001', E'0f92f830-8a3c-4e0c-b40a-0645bd96cb3c', NULL, E'2022-04-03 19:31:35', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'708078434558935040', E'622227747938373638', E'622227747942568001', E'0f92f830-8a3c-4e0c-b40a-0645bd96cb3c', NULL, E'2022-04-03 19:31:59', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'708078523507539968', E'622227747938373638', E'622227747942568001', E'04ee2f33-3ced-4c23-992c-5c85b03dbc20', NULL, E'2022-04-03 19:32:21', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'708078646136406016', E'622227747938373638', E'622227747942568001', E'c031c924-ee84-4719-843f-493409181440', NULL, E'2022-04-03 19:32:50', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'708081775649226752', E'622227747938373638', E'622227747942568001', E'913f7a47-8cdc-4f5f-bc99-1f580f86a63e', NULL, E'2022-04-03 19:45:16', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'708083285019852800', E'622227747938373638', E'622227747942568001', E'8c3da816-882c-466d-aec2-92a02cbbe5d7', NULL, E'2022-04-03 19:51:16', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'708083285019852801', E'622227747938373638', E'622227747942568001', E'18a82e89-56f7-4538-975f-7de500e5e15e', NULL, E'2022-04-03 19:51:16', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'708083285019852802', E'622227747938373638', E'622227747942568001', E'04ee2f33-3ced-4c23-992c-5c85b03dbc20', NULL, E'2022-04-03 19:51:16', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'708083285019852803', E'622227747938373638', E'622227747942568001', E'f8091914-e67c-4377-a68e-0798b31f33bb', NULL, E'2022-04-03 19:51:16', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'708083285019852804', E'622227747938373638', E'622227747942568001', E'c9991957-2579-4529-86d6-ea386e37c27a', NULL, E'2022-04-03 19:51:16', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'708083285019852806', E'622227747938373638', E'622227747942568001', E'fddc2287-0628-489f-807d-7bcb49285632', NULL, E'2022-04-03 19:51:16', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'708083657012674560', E'622227747938373638', E'622227747942568002', E'ab6c11c9-7aa8-4428-beb2-f1ab77e8796e', NULL, E'2022-04-03 19:52:45', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'708083657012674561', E'622227747938373638', E'622227747942568002', E'7829374f-4503-4738-b661-72c2efb6d640', NULL, E'2022-04-03 19:52:45', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'708083657012674562', E'622227747938373638', E'622227747942568002', E'231c6a4b-a903-47ed-8110-4664371e326e', NULL, E'2022-04-03 19:52:45', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'708083657012674563', E'622227747938373638', E'622227747942568002', E'1824404a-5979-40f3-9d0e-2c1196209afb', NULL, E'2022-04-03 19:52:45', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'708083657012674564', E'622227747938373638', E'622227747942568002', E'0f92f830-8a3c-4e0c-b40a-0645bd96cb3c', NULL, E'2022-04-03 19:52:45', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'708083682908307456', E'622227747938373638', E'622227747942568002', E'a2b1968e-78ab-46f6-96b2-7b6bab334218', NULL, E'2022-04-03 19:52:51', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'708083682908307457', E'622227747938373638', E'622227747942568002', E'8aca327e-033e-4867-b991-6fb9303f5aaa', NULL, E'2022-04-03 19:52:51', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'708083682908307458', E'622227747938373638', E'622227747942568002', E'80a7a954-7dfa-454b-b4ed-3f52feeef8a3', NULL, E'2022-04-03 19:52:51', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'708083682908307459', E'622227747938373638', E'622227747942568002', E'463da0ad-55f2-486a-a01f-66b44a2ba18d', NULL, E'2022-04-03 19:52:51', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'708083682908307460', E'622227747938373638', E'622227747942568002', E'27e7471a-ba2c-4dde-9228-c804f096d19d', NULL, E'2022-04-03 19:52:51', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'708083730224250880', E'622227747938373638', E'622227747942568002', E'c031c924-ee84-4719-843f-493409181440', NULL, E'2022-04-03 19:53:02', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'708083730224250881', E'622227747938373638', E'622227747942568002', E'913f7a47-8cdc-4f5f-bc99-1f580f86a63e', NULL, E'2022-04-03 19:53:02', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'708083730224250882', E'622227747938373638', E'622227747942568002', E'6536e3f3-284d-4156-807f-bdc7caf46c64', NULL, E'2022-04-03 19:53:02', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'708083730224250883', E'622227747938373638', E'622227747942568002', E'4d7cb056-7c3f-44b5-8be6-98a088b8d09f', NULL, E'2022-04-03 19:53:02', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'708083730224250884', E'622227747938373638', E'622227747942568002', E'3b795490-4a46-4122-b656-861f871725c3', NULL, E'2022-04-03 19:53:02', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'708083730224250887', E'622227747938373638', E'622227747942568002', E'04ee2f33-3ced-4c23-992c-5c85b03dbc20', NULL, E'2022-04-03 19:53:02', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'708084240666853378', E'622227747938373638', E'622227747942568002', E'a2b1968e-78ab-46f6-96b2-7b6bab334218', NULL, E'2022-04-03 19:55:04', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'709137312218349569', E'622227747938373638', E'622227747942568003', E'e238e0d1-b3db-472f-b0bf-38d889ba2df3', NULL, E'2022-04-06 17:39:36', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'709137312218349570', E'622227747938373638', E'622227747942568003', E'70b2522b-e943-4d8e-860f-7c5ae7d9569f', NULL, E'2022-04-06 17:39:36', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'709137312218349571', E'622227747938373638', E'622227747942568003', E'3b795490-4a46-4122-b656-861f871725c3', NULL, E'2022-04-06 17:39:36', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'709744653292797953', E'622227747938373638', E'622227747942568001', E'8c3da816-882c-466d-aec2-92a02cbbe5d7', NULL, E'2022-04-08 09:52:57', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'709744653292797954', E'622227747938373638', E'622227747942568001', E'18a82e89-56f7-4538-975f-7de500e5e15e', NULL, E'2022-04-08 09:52:57', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'709744653292797955', E'622227747938373638', E'622227747942568001', E'04ee2f33-3ced-4c23-992c-5c85b03dbc20', NULL, E'2022-04-08 09:52:57', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'70980178-5623-4f88-83b0-0b999ee9af63', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'7452d560-0bc0-4bda-b2eb-d9dc7432d973', E'3b795490-4a46-4122-b656-861f871725c3', NULL, E'2020-07-19 09:59:14', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'718908754229198849', E'622227747938373638', E'622227747942568001', E'ab6c11c9-7aa8-4428-beb2-f1ab77e8796e', NULL, E'2022-05-03 16:47:49', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'718908754229198850', E'622227747938373638', E'622227747942568001', E'7829374f-4503-4738-b661-72c2efb6d640', NULL, E'2022-05-03 16:47:49', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'718908754229198851', E'622227747938373638', E'622227747942568001', E'231c6a4b-a903-47ed-8110-4664371e326e', NULL, E'2022-05-03 16:47:49', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'718908754229198852', E'622227747938373638', E'622227747942568001', E'1824404a-5979-40f3-9d0e-2c1196209afb', NULL, E'2022-05-03 16:47:49', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'718908754229198853', E'622227747938373638', E'622227747942568001', E'0f92f830-8a3c-4e0c-b40a-0645bd96cb3c', NULL, E'2022-05-03 16:47:49', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'719ab575-4f09-4f37-9cba-1ec4e54b959d', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'7452d560-0bc0-4bda-b2eb-d9dc7432d973', E'70b2522b-e943-4d8e-860f-7c5ae7d9569f', NULL, E'2020-07-19 09:59:14', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'71b982fd-e341-4464-ba07-930772904f1f', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'27e7471a-ba2c-4dde-9228-c804f096d19d', NULL, E'2020-07-19 09:59:21', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'71c51bae-e0ed-4069-98b6-9fcd1171703f', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'8c3da816-882c-466d-aec2-92a02cbbe5d7', NULL, E'2020-07-19 09:59:21', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'724969261281312769', E'622227747938373638', E'622227747942568001', E'a2b1968e-78ab-46f6-96b2-7b6bab334218', NULL, E'2022-05-20 10:10:06', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'724969261281312770', E'622227747938373638', E'622227747942568001', E'8aca327e-033e-4867-b991-6fb9303f5aaa', NULL, E'2022-05-20 10:10:06', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'724969261281312771', E'622227747938373638', E'622227747942568001', E'80a7a954-7dfa-454b-b4ed-3f52feeef8a3', NULL, E'2022-05-20 10:10:06', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'724969261281312772', E'622227747938373638', E'622227747942568001', E'463da0ad-55f2-486a-a01f-66b44a2ba18d', NULL, E'2022-05-20 10:10:06', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'724969261281312773', E'622227747938373638', E'622227747942568001', E'27e7471a-ba2c-4dde-9228-c804f096d19d', NULL, E'2022-05-20 10:10:06', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'725664661109735424', E'622227747938373638', E'622227747942568005', E'c031c924-ee84-4719-843f-493409181440', NULL, E'2022-05-22 08:13:23', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'725664661109735425', E'622227747938373638', E'622227747942568005', E'913f7a47-8cdc-4f5f-bc99-1f580f86a63e', NULL, E'2022-05-22 08:13:23', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'725664661109735426', E'622227747938373638', E'622227747942568005', E'6536e3f3-284d-4156-807f-bdc7caf46c64', NULL, E'2022-05-22 08:13:23', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'725664661109735427', E'622227747938373638', E'622227747942568005', E'4d7cb056-7c3f-44b5-8be6-98a088b8d09f', NULL, E'2022-05-22 08:13:23', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'725664661109735428', E'622227747938373638', E'622227747942568005', E'3b795490-4a46-4122-b656-861f871725c3', NULL, E'2022-05-22 08:13:23', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'725664661109735429', E'622227747938373638', E'622227747942568005', E'27e7471a-ba2c-4dde-9228-c804f096d19d', NULL, E'2022-05-22 08:13:23', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'725664661109735430', E'622227747938373638', E'622227747942568005', E'0f92f830-8a3c-4e0c-b40a-0645bd96cb3c', NULL, E'2022-05-22 08:13:23', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'725664661109735431', E'622227747938373638', E'622227747942568005', E'04ee2f33-3ced-4c23-992c-5c85b03dbc20', NULL, E'2022-05-22 08:13:23', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'725732657169694721', E'622227747938373638', E'622227747942568009', E'fcbc7a33-ad60-4d63-9b14-9b41120bdb49', NULL, E'2022-05-22 12:43:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'725732657169694722', E'622227747938373638', E'622227747942568009', E'f44a0273-ba7c-4301-b84f-c9ba9f199cda', NULL, E'2022-05-22 12:43:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'725732657169694723', E'622227747938373638', E'622227747942568009', E'ab715383-8fa5-4225-b0a2-ab01991b98e7', NULL, E'2022-05-22 12:43:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'725732657169694724', E'622227747938373638', E'622227747942568009', E'237e3cce-7cb7-4646-bc1a-6ca941931b5c', NULL, E'2022-05-22 12:43:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'725732657169694725', E'622227747938373638', E'622227747942568009', E'1be7c248-6682-44ff-b688-4310d2e9be8a', NULL, E'2022-05-22 12:43:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'725732657169694726', E'622227747938373638', E'622227747942568009', E'4d7cb056-7c3f-44b5-8be6-98a088b8d09f', NULL, E'2022-05-22 12:43:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'725732657169694727', E'622227747938373638', E'622227747942568009', E'e238e0d1-b3db-472f-b0bf-38d889ba2df3', NULL, E'2022-05-22 12:43:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'725732657169694728', E'622227747938373638', E'622227747942568009', E'70b2522b-e943-4d8e-860f-7c5ae7d9569f', NULL, E'2022-05-22 12:43:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'725732657169694729', E'622227747938373638', E'622227747942568009', E'3b795490-4a46-4122-b656-861f871725c3', NULL, E'2022-05-22 12:43:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'731165705138864129', E'622227747938373638', E'622178518125510656', E'8c3da816-882c-466d-aec2-92a02cbbe5d7', NULL, E'2022-06-06 12:32:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'731165705138864130', E'622227747938373638', E'622178518125510656', E'18a82e89-56f7-4538-975f-7de500e5e15e', NULL, E'2022-06-06 12:32:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'731165705138864131', E'622227747938373638', E'622178518125510656', E'04ee2f33-3ced-4c23-992c-5c85b03dbc20', NULL, E'2022-06-06 12:32:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'731165705138864132', E'622227747938373638', E'622178518125510656', E'ab6c11c9-7aa8-4428-beb2-f1ab77e8796e', NULL, E'2022-06-06 12:32:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'731165705138864133', E'622227747938373638', E'622178518125510656', E'7829374f-4503-4738-b661-72c2efb6d640', NULL, E'2022-06-06 12:32:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'731165705138864134', E'622227747938373638', E'622178518125510656', E'231c6a4b-a903-47ed-8110-4664371e326e', NULL, E'2022-06-06 12:32:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'731165705138864135', E'622227747938373638', E'622178518125510656', E'1824404a-5979-40f3-9d0e-2c1196209afb', NULL, E'2022-06-06 12:32:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'731165705138864136', E'622227747938373638', E'622178518125510656', E'0f92f830-8a3c-4e0c-b40a-0645bd96cb3c', NULL, E'2022-06-06 12:32:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'731167831399333889', E'622227747938373638', E'622178518125510656', E'e238e0d1-b3db-472f-b0bf-38d889ba2df3', NULL, E'2022-06-06 12:41:01', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'731167831399333890', E'622227747938373638', E'622178518125510656', E'70b2522b-e943-4d8e-860f-7c5ae7d9569f', NULL, E'2022-06-06 12:41:01', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'731167831399333891', E'622227747938373638', E'622178518125510656', E'3b795490-4a46-4122-b656-861f871725c3', NULL, E'2022-06-06 12:41:01', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'731167831399333892', E'622227747938373638', E'622178518125510656', E'a2b1968e-78ab-46f6-96b2-7b6bab334218', NULL, E'2022-06-06 12:41:01', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'731167831399333893', E'622227747938373638', E'622178518125510656', E'8aca327e-033e-4867-b991-6fb9303f5aaa', NULL, E'2022-06-06 12:41:01', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'731167831399333894', E'622227747938373638', E'622178518125510656', E'80a7a954-7dfa-454b-b4ed-3f52feeef8a3', NULL, E'2022-06-06 12:41:01', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'731167831399333895', E'622227747938373638', E'622178518125510656', E'463da0ad-55f2-486a-a01f-66b44a2ba18d', NULL, E'2022-06-06 12:41:01', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'731167831399333896', E'622227747938373638', E'622178518125510656', E'27e7471a-ba2c-4dde-9228-c804f096d19d', NULL, E'2022-06-06 12:41:01', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'731207433472442369', E'622227747938373638', E'622178881788444672', E'8c3da816-882c-466d-aec2-92a02cbbe5d7', NULL, E'2022-06-06 15:18:22', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'731207433472442370', E'622227747938373638', E'622178881788444672', E'18a82e89-56f7-4538-975f-7de500e5e15e', NULL, E'2022-06-06 15:18:22', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'731207433472442371', E'622227747938373638', E'622178881788444672', E'04ee2f33-3ced-4c23-992c-5c85b03dbc20', NULL, E'2022-06-06 15:18:22', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'731210449810358273', E'622227747938373638', E'622178518125510656', E'fcbc7a33-ad60-4d63-9b14-9b41120bdb49', NULL, E'2022-06-06 15:30:22', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'731210449810358274', E'622227747938373638', E'622178518125510656', E'f44a0273-ba7c-4301-b84f-c9ba9f199cda', NULL, E'2022-06-06 15:30:22', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'731210449810358275', E'622227747938373638', E'622178518125510656', E'ab715383-8fa5-4225-b0a2-ab01991b98e7', NULL, E'2022-06-06 15:30:22', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'731210449810358276', E'622227747938373638', E'622178518125510656', E'237e3cce-7cb7-4646-bc1a-6ca941931b5c', NULL, E'2022-06-06 15:30:22', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'731210449810358277', E'622227747938373638', E'622178518125510656', E'1be7c248-6682-44ff-b688-4310d2e9be8a', NULL, E'2022-06-06 15:30:22', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'731210449810358278', E'622227747938373638', E'622178518125510656', E'4d7cb056-7c3f-44b5-8be6-98a088b8d09f', NULL, E'2022-06-06 15:30:22', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'731210570216243201', E'622227747938373638', E'622178881788444672', E'ab6c11c9-7aa8-4428-beb2-f1ab77e8796e', NULL, E'2022-06-06 15:30:50', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'731210570216243202', E'622227747938373638', E'622178881788444672', E'7829374f-4503-4738-b661-72c2efb6d640', NULL, E'2022-06-06 15:30:50', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'731210570216243203', E'622227747938373638', E'622178881788444672', E'231c6a4b-a903-47ed-8110-4664371e326e', NULL, E'2022-06-06 15:30:50', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'731210570216243204', E'622227747938373638', E'622178881788444672', E'1824404a-5979-40f3-9d0e-2c1196209afb', NULL, E'2022-06-06 15:30:50', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'731210570216243205', E'622227747938373638', E'622178881788444672', E'0f92f830-8a3c-4e0c-b40a-0645bd96cb3c', NULL, E'2022-06-06 15:30:50', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'731285659876065281', E'622227747938373638', E'622178881788444672', E'e238e0d1-b3db-472f-b0bf-38d889ba2df3', NULL, E'2022-06-06 20:29:13', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'731285659876065282', E'622227747938373638', E'622178881788444672', E'70b2522b-e943-4d8e-860f-7c5ae7d9569f', NULL, E'2022-06-06 20:29:13', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'731285659876065283', E'622227747938373638', E'622178881788444672', E'3b795490-4a46-4122-b656-861f871725c3', NULL, E'2022-06-06 20:29:13', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'73d40b7d-3998-45cb-9529-149b99de471b', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'231c6a4b-a903-47ed-8110-4664371e326e', NULL, E'2020-07-19 09:59:21', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'74624f4b-6b6f-4c76-ab1e-20971e2886f3', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'359520ca-6699-45cd-b010-b288c9f1b835', E'70b2522b-e943-4d8e-860f-7c5ae7d9569f', NULL, E'2020-07-19 09:59:35', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'775865666359001089', E'622227747938373638', E'622178269462003712', E'a2b1968e-78ab-46f6-96b2-7b6bab334218', NULL, E'2022-10-07 20:54:15', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'775865666359001090', E'622227747938373638', E'622178269462003712', E'8aca327e-033e-4867-b991-6fb9303f5aaa', NULL, E'2022-10-07 20:54:15', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'775865666359001091', E'622227747938373638', E'622178269462003712', E'80a7a954-7dfa-454b-b4ed-3f52feeef8a3', NULL, E'2022-10-07 20:54:15', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'775865666359001092', E'622227747938373638', E'622178269462003712', E'463da0ad-55f2-486a-a01f-66b44a2ba18d', NULL, E'2022-10-07 20:54:15', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'775865666359001093', E'622227747938373638', E'622178269462003712', E'27e7471a-ba2c-4dde-9228-c804f096d19d', NULL, E'2022-10-07 20:54:15', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'775865666359001094', E'622227747938373638', E'622178269462003712', E'ab6c11c9-7aa8-4428-beb2-f1ab77e8796e', NULL, E'2022-10-07 20:54:15', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'775865666359001095', E'622227747938373638', E'622178269462003712', E'7829374f-4503-4738-b661-72c2efb6d640', NULL, E'2022-10-07 20:54:15', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'775865666359001096', E'622227747938373638', E'622178269462003712', E'231c6a4b-a903-47ed-8110-4664371e326e', NULL, E'2022-10-07 20:54:15', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'775865666359001097', E'622227747938373638', E'622178269462003712', E'1824404a-5979-40f3-9d0e-2c1196209afb', NULL, E'2022-10-07 20:54:15', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'775865666359001098', E'622227747938373638', E'622178269462003712', E'0f92f830-8a3c-4e0c-b40a-0645bd96cb3c', NULL, E'2022-10-07 20:54:15', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'775865666359001099', E'622227747938373638', E'622178269462003712', E'8c3da816-882c-466d-aec2-92a02cbbe5d7', NULL, E'2022-10-07 20:54:15', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'775865666359001100', E'622227747938373638', E'622178269462003712', E'18a82e89-56f7-4538-975f-7de500e5e15e', NULL, E'2022-10-07 20:54:15', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'775865666359001101', E'622227747938373638', E'622178269462003712', E'04ee2f33-3ced-4c23-992c-5c85b03dbc20', NULL, E'2022-10-07 20:54:15', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'776068298960797696', E'622227747938373638', E'ROLE_ADMINISTRATORS', E'c031c924-ee84-4719-843f-493409181440', NULL, E'2022-10-08 10:19:26', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'776068298960797697', E'622227747938373638', E'ROLE_ADMINISTRATORS', E'913f7a47-8cdc-4f5f-bc99-1f580f86a63e', NULL, E'2022-10-08 10:19:26', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'776068298960797698', E'622227747938373638', E'ROLE_ADMINISTRATORS', E'6536e3f3-284d-4156-807f-bdc7caf46c64', NULL, E'2022-10-08 10:19:26', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'776068298960797699', E'622227747938373638', E'ROLE_ADMINISTRATORS', E'4d7cb056-7c3f-44b5-8be6-98a088b8d09f', NULL, E'2022-10-08 10:19:26', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'776068298960797700', E'622227747938373638', E'ROLE_ADMINISTRATORS', E'3b795490-4a46-4122-b656-861f871725c3', NULL, E'2022-10-08 10:19:26', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'776068298960797701', E'622227747938373638', E'ROLE_ADMINISTRATORS', E'27e7471a-ba2c-4dde-9228-c804f096d19d', NULL, E'2022-10-08 10:19:26', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'776068298960797702', E'622227747938373638', E'ROLE_ADMINISTRATORS', E'0f92f830-8a3c-4e0c-b40a-0645bd96cb3c', NULL, E'2022-10-08 10:19:26', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'776068298960797703', E'622227747938373638', E'ROLE_ADMINISTRATORS', E'04ee2f33-3ced-4c23-992c-5c85b03dbc20', NULL, E'2022-10-08 10:19:26', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'77ac0d15-cdaa-4419-88cd-f1ec8f33b6d3', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'8a1ba67d-29a3-472d-9d8c-beffb14c48ce', E'75b21762-08c9-4e37-bf62-5e762339e159', NULL, E'2020-07-19 10:00:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'77fe24af-41a9-4bbf-8eb5-5bafb50d2d8b', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'8a1ba67d-29a3-472d-9d8c-beffb14c48ce', E'fddc2287-0628-489f-807d-7bcb49285632', NULL, E'2020-07-19 10:00:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'781c447d-109a-4451-b2da-e855b6811ade', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'dff01736-64e9-42ef-92bd-cda2ca91044f', E'1be7c248-6682-44ff-b688-4310d2e9be8a', NULL, E'2020-07-19 10:01:26', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'791806907185627137', E'622227747938373638', E'622178269462003712', E'e238e0d1-b3db-472f-b0bf-38d889ba2df3', NULL, E'2022-11-20 20:39:03', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'791806907185627138', E'622227747938373638', E'622178269462003712', E'70b2522b-e943-4d8e-860f-7c5ae7d9569f', NULL, E'2022-11-20 20:39:03', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'791806907185627139', E'622227747938373638', E'622178269462003712', E'3b795490-4a46-4122-b656-861f871725c3', NULL, E'2022-11-20 20:39:03', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'79ebe238-0bd5-4c8f-af72-e001c04f2570', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'04ee2f33-3ced-4c23-992c-5c85b03dbc20', NULL, E'2020-07-19 09:59:21', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'7d5dc3f3-70d6-46aa-8608-f2ad9307c2d9', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'80a7a954-7dfa-454b-b4ed-3f52feeef8a3', NULL, E'2020-07-19 00:55:45', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'7f681ba5-11f3-4a6b-8c8b-0e2f35ab73ff', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'8aca327e-033e-4867-b991-6fb9303f5aaa', NULL, E'2020-07-19 00:55:45', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'805511a2-7a83-4f98-850c-a932f1925040', E'maxkey_mgt', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'222', NULL, E'2020-04-29 18:34:01', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'80d1b53a-9769-446d-9db8-a37eaffdcccc', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'8a1ba67d-29a3-472d-9d8c-beffb14c48ce', E'8c3da816-882c-466d-aec2-92a02cbbe5d7', NULL, E'2020-07-19 10:00:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'82ae8558-b61a-4e21-a357-4e4c336ca442', E'maxkey_mgt', E'f2f7f1bb-245c-4f22-bf8e-9d9f6e30b699', E'b1c9395b-c045-4e0b-9b33-effa892d923d', NULL, E'2020-05-09 23:33:04', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'84506397-fe0b-4b5e-955b-05c5820ee08a', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'dff01736-64e9-42ef-92bd-cda2ca91044f', E'fcbc7a33-ad60-4d63-9b14-9b41120bdb49', NULL, E'2020-07-19 10:01:26', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'84a00290-af73-4223-abb1-3baf51998b41', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'8a1ba67d-29a3-472d-9d8c-beffb14c48ce', E'70b2522b-e943-4d8e-860f-7c5ae7d9569f', NULL, E'2020-07-19 10:00:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'86c0ac6d-baf7-4176-9d8e-0f2082e9fa94', E'maxkey_mgt', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'b1c9395b-c045-4e0b-9b33-effa892d923d', NULL, E'2020-04-29 19:03:29', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'8ad9eab1-e7b7-466a-837d-8eda182ddae6', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'dff01736-64e9-42ef-92bd-cda2ca91044f', E'237e3cce-7cb7-4646-bc1a-6ca941931b5c', NULL, E'2020-07-19 10:01:26', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'8d404bb7-fcc5-4dc5-b8eb-2f896a3bff9d', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'dff01736-64e9-42ef-92bd-cda2ca91044f', E'3b795490-4a46-4122-b656-861f871725c3', NULL, E'2020-07-19 10:01:26', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'8d48cd0d-ef64-461e-986a-d3f74bf728e1', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'dff01736-64e9-42ef-92bd-cda2ca91044f', E'f44a0273-ba7c-4301-b84f-c9ba9f199cda', NULL, E'2020-07-19 10:01:26', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'8df730d3-9a66-49c4-a1aa-dd120b64fa38', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'dff01736-64e9-42ef-92bd-cda2ca91044f', E'70b2522b-e943-4d8e-860f-7c5ae7d9569f', NULL, E'2020-07-19 10:01:26', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'8fac82f8-8722-4d2a-b80a-03a60dcf2fb5', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'8a1ba67d-29a3-472d-9d8c-beffb14c48ce', E'04ee2f33-3ced-4c23-992c-5c85b03dbc20', NULL, E'2020-07-19 10:00:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'904105e7-0cd4-4823-96a4-96d2d4ccdab3', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'8a1ba67d-29a3-472d-9d8c-beffb14c48ce', E'80a7a954-7dfa-454b-b4ed-3f52feeef8a3', NULL, E'2020-07-19 10:00:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'90c03489-4cab-4180-b048-e5232a863053', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'872de4f0-8ae3-4e16-b8ef-2e87058045b7', E'c031c924-ee84-4719-843f-493409181440', NULL, E'2020-07-19 10:00:19', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'93d8f54b-585a-4451-936b-fa2a24b86c94', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'e0d12156-63f4-4142-9dff-91342149262b', E'75b21762-08c9-4e37-bf62-5e762339e159', NULL, E'2020-07-19 10:01:40', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'944312bd-c0e2-4713-9322-5aded716017c', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'7452d560-0bc0-4bda-b2eb-d9dc7432d973', E'32ed9486-f002-4ee9-8d91-97b6b5a3bada', NULL, E'2020-07-19 09:59:14', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'94c60880-9b12-452b-a1a7-89617e9c7caf', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'8a1ba67d-29a3-472d-9d8c-beffb14c48ce', E'f8091914-e67c-4377-a68e-0798b31f33bb', NULL, E'2020-07-19 10:00:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'94d6d706-41e1-4f94-9839-0f1263c6f4ad', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'ce609834-e01c-4336-af95-373cf08447aa', E'237e3cce-7cb7-4646-bc1a-6ca941931b5c', NULL, E'2020-07-19 10:00:54', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'95862ee5-1cb3-4fc8-bd3c-8f712cd48bf3', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'8a1ba67d-29a3-472d-9d8c-beffb14c48ce', E'ab715383-8fa5-4225-b0a2-ab01991b98e7', NULL, E'2020-07-19 10:00:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'960b7093-6ddf-4ec0-b630-c2191142782f', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'8a1ba67d-29a3-472d-9d8c-beffb14c48ce', E'a2b1968e-78ab-46f6-96b2-7b6bab334218', NULL, E'2020-07-19 10:00:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'96a307e1-c635-4568-83e1-9585da97671a', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'7452d560-0bc0-4bda-b2eb-d9dc7432d973', E'a2b1968e-78ab-46f6-96b2-7b6bab334218', NULL, E'2020-07-19 09:59:14', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'9ac74dad-ead5-4169-852f-ef14cc93e55e', E'maxkey_mgt', E'f2f7f1bb-245c-4f22-bf8e-9d9f6e30b699', E'222', NULL, E'2020-05-09 23:33:04', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'9d799cd1-9d34-4de6-afc4-9c4cebee0ae7', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'e0d12156-63f4-4142-9dff-91342149262b', E'6536e3f3-284d-4156-807f-bdc7caf46c64', NULL, E'2020-07-19 10:01:40', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'9da18525-3a49-4421-b523-a56bf60026b0', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'fddc2287-0628-489f-807d-7bcb49285632', NULL, E'2020-07-19 00:55:45', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'9e53b113-f53a-4b87-9a73-531e29bc1fcf', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'f2f7f1bb-245c-4f22-bf8e-9d9f6e30b699', E'231c6a4b-a903-47ed-8110-4664371e326e', NULL, E'2020-07-19 10:01:59', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'a0e22c37-bf90-49d1-9a63-7a6946e1d005', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'7452d560-0bc0-4bda-b2eb-d9dc7432d973', E'6536e3f3-284d-4156-807f-bdc7caf46c64', NULL, E'2020-07-19 09:59:14', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'a10a45f6-42b6-4986-aad1-0e59364d3000', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'ab6c11c9-7aa8-4428-beb2-f1ab77e8796e', NULL, E'2020-07-19 00:55:45', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'a4cbfffc-adc8-4619-921f-0c6ddacc7d18', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'7452d560-0bc0-4bda-b2eb-d9dc7432d973', E'27e7471a-ba2c-4dde-9228-c804f096d19d', NULL, E'2020-07-19 09:59:14', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'a9734894-0db1-4a40-ae66-31deaf47c753', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'7829374f-4503-4738-b661-72c2efb6d640', NULL, E'2020-07-19 09:59:21', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'abdb8231-bfb2-4495-99c1-fcb93353f448', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'ab715383-8fa5-4225-b0a2-ab01991b98e7', NULL, E'2020-07-19 00:55:45', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'ada821dd-9113-4aa8-a72a-bcd2f3230928', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'e0d12156-63f4-4142-9dff-91342149262b', E'a2b1968e-78ab-46f6-96b2-7b6bab334218', NULL, E'2020-07-19 10:01:40', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'aebb7222-89aa-46fd-a247-05f9815d41c4', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'a2b1968e-78ab-46f6-96b2-7b6bab334218', NULL, E'2020-07-19 09:59:21', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'af77572c-d7ce-4eb5-ac47-eb3eeda4f94c', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'1824404a-5979-40f3-9d0e-2c1196209afb', NULL, E'2020-07-19 00:55:45', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'b00ea7b3-f03c-454e-b370-6b0aa4c29e8a', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'f2f7f1bb-245c-4f22-bf8e-9d9f6e30b699', E'7829374f-4503-4738-b661-72c2efb6d640', NULL, E'2020-07-19 10:01:59', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'b1336ef9-8c8c-4c18-9d82-1b7e087db2ef', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'8c3da816-882c-466d-aec2-92a02cbbe5d7', NULL, E'2020-07-19 00:55:45', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'b29aaa76-0c34-46f4-965f-fb109bdb0e9b', E'maxkey_mgt', E'8a1ba67d-29a3-472d-9d8c-beffb14c48ce', E'cc121e8d-74f9-4d90-8b34-5d7bc34ca287', NULL, E'2020-06-06 20:10:33', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'b2f0468a-0977-46db-9b1b-d769e265312c', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'8a1ba67d-29a3-472d-9d8c-beffb14c48ce', E'27e7471a-ba2c-4dde-9228-c804f096d19d', NULL, E'2020-07-19 10:00:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'b309cbeb-07e8-466f-920e-ecd3aaa73cb6', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'f8091914-e67c-4377-a68e-0798b31f33bb', NULL, E'2020-07-19 00:55:45', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'b5a51424-659e-47d3-9fde-5544001e33a7', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'8a1ba67d-29a3-472d-9d8c-beffb14c48ce', E'32ed9486-f002-4ee9-8d91-97b6b5a3bada', NULL, E'2020-07-19 10:00:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'b79f676a-9a3c-4734-a86f-8f5b18118fc9', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'e0d12156-63f4-4142-9dff-91342149262b', E'4de2475d-2a31-4178-af34-12eb39248d1d', NULL, E'2020-07-19 10:01:40', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'ba12a064-cbaa-4ac9-a5d1-e9c404d4b909', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'359520ca-6699-45cd-b010-b288c9f1b835', E'8c3da816-882c-466d-aec2-92a02cbbe5d7', NULL, E'2021-04-17 16:49:43', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'bbd6cb09-d66b-40e1-a821-5657e4b90d05', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'913f7a47-8cdc-4f5f-bc99-1f580f86a63e', NULL, E'2020-07-19 00:55:45', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'bcd5e959-3e6f-4142-a664-7a7a40ca04a1', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'7452d560-0bc0-4bda-b2eb-d9dc7432d973', E'231c6a4b-a903-47ed-8110-4664371e326e', NULL, E'2020-07-19 09:59:14', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'bdb982da-e901-4420-b22b-f987ec56ff62', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'359520ca-6699-45cd-b010-b288c9f1b835', E'04ee2f33-3ced-4c23-992c-5c85b03dbc20', NULL, E'2021-04-17 16:49:43', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'be437677-6fde-4f63-863d-9129c39898eb', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'04ee2f33-3ced-4c23-992c-5c85b03dbc20', NULL, E'2020-07-19 00:55:45', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'be79cbde-00f8-4319-a397-815e1a0b5ff5', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'1be7c248-6682-44ff-b688-4310d2e9be8a', NULL, E'2020-07-19 00:55:45', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'be7a2060-9282-4dc3-bcb3-3c25c3c5ab50', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'18a82e89-56f7-4538-975f-7de500e5e15e', NULL, E'2020-07-19 00:55:45', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'bfb85354-defc-4650-aadc-10a270979214', E'maxkey_mgt', E'8a1ba67d-29a3-472d-9d8c-beffb14c48ce', E'b1c9395b-c045-4e0b-9b33-effa892d923d', NULL, E'2020-04-29 20:47:59', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'c10d68ab-c2d3-42b7-8646-8111dc94c29d', E'maxkey_mgt', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'd9abaad9-a18b-4042-bdf5-3c221a4001ee', NULL, E'2020-04-29 18:34:01', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'c2ffb017-5ce2-487b-a039-f86fb02707aa', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'7452d560-0bc0-4bda-b2eb-d9dc7432d973', E'1be7c248-6682-44ff-b688-4310d2e9be8a', NULL, E'2020-07-19 09:59:14', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'c3265ba1-3ad0-4143-9334-bcbc42716b30', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'32ed9486-f002-4ee9-8d91-97b6b5a3bada', NULL, E'2020-07-19 09:59:21', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'c37705d3-5959-43ac-8149-9370eac290e5', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'231c6a4b-a903-47ed-8110-4664371e326e', NULL, E'2020-07-19 00:55:45', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'c62fd1f0-abde-4fb5-af03-3ca45ee5f2e1', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'8a1ba67d-29a3-472d-9d8c-beffb14c48ce', E'ab6c11c9-7aa8-4428-beb2-f1ab77e8796e', NULL, E'2020-07-19 10:00:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'c643a803-a006-41fe-a6f5-0e89d458b07e', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'7452d560-0bc0-4bda-b2eb-d9dc7432d973', E'7829374f-4503-4738-b661-72c2efb6d640', NULL, E'2020-07-19 09:59:14', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'ca2d6d5f-f8ba-4dfa-8604-438659432e7c', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'ce609834-e01c-4336-af95-373cf08447aa', E'fcbc7a33-ad60-4d63-9b14-9b41120bdb49', NULL, E'2020-07-19 10:00:54', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'ca66b14b-2805-4257-aa6c-d5fe96f91655', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'8a1ba67d-29a3-472d-9d8c-beffb14c48ce', E'7829374f-4503-4738-b661-72c2efb6d640', NULL, E'2020-07-19 10:00:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'cb860c14-66c8-4eab-817b-84e0c48546bb', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'4d7cb056-7c3f-44b5-8be6-98a088b8d09f', NULL, E'2020-07-19 00:55:45', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'cd7efbf2-c939-4e4b-89c8-d6cc64891dfe', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'8a1ba67d-29a3-472d-9d8c-beffb14c48ce', E'c031c924-ee84-4719-843f-493409181440', NULL, E'2020-07-19 10:00:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'ce253f2f-e390-484a-a903-699d08bbbd3e', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'ce609834-e01c-4336-af95-373cf08447aa', E'1be7c248-6682-44ff-b688-4310d2e9be8a', NULL, E'2020-07-19 10:00:54', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'cf07c7b0-6220-45ab-a5ac-5c0faa749478', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'359520ca-6699-45cd-b010-b288c9f1b835', E'e238e0d1-b3db-472f-b0bf-38d889ba2df3', NULL, E'2020-07-19 09:59:35', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'd0137026-5b22-48f1-b9fc-b41e7e977dda', E'maxkey_mgt', E'f2f7f1bb-245c-4f22-bf8e-9d9f6e30b699', E'cc121e8d-74f9-4d90-8b34-5d7bc34ca287', NULL, E'2020-05-09 23:33:04', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'd05d701d-61b2-441a-af1b-06fb7dea1fdd', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'70b2522b-e943-4d8e-860f-7c5ae7d9569f', NULL, E'2020-07-19 09:59:21', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'd0fbebbb-67ac-4e14-830c-6e1f8afdc322', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'7452d560-0bc0-4bda-b2eb-d9dc7432d973', E'ab6c11c9-7aa8-4428-beb2-f1ab77e8796e', NULL, E'2020-07-19 09:59:14', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'd177e9dd-6e5a-4b8e-a5db-3e9a58245a38', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'7452d560-0bc0-4bda-b2eb-d9dc7432d973', E'237e3cce-7cb7-4646-bc1a-6ca941931b5c', NULL, E'2020-07-19 09:59:14', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'd358dee8-8956-41cc-9345-fac5ae92564f', E'maxkey_mgt', E'8a1ba67d-29a3-472d-9d8c-beffb14c48ce', E'd9abaad9-a18b-4042-bdf5-3c221a4001ee', NULL, E'2020-04-29 20:47:59', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'd3b0d1b2-021b-4649-9ff4-ba0b1e23dc12', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'7452d560-0bc0-4bda-b2eb-d9dc7432d973', E'0f92f830-8a3c-4e0c-b40a-0645bd96cb3c', NULL, E'2020-07-19 09:59:14', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'd3cc26c5-7f68-400e-8102-f0cc76a7493a', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'8a1ba67d-29a3-472d-9d8c-beffb14c48ce', E'e238e0d1-b3db-472f-b0bf-38d889ba2df3', NULL, E'2020-07-19 10:00:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'd43f27b4-8933-4d67-b34c-0825839fc85c', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'f2f7f1bb-245c-4f22-bf8e-9d9f6e30b699', E'0f92f830-8a3c-4e0c-b40a-0645bd96cb3c', NULL, E'2020-07-19 10:01:59', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'd4fce231-635d-47da-bdea-07adb115e8de', E'maxkey_mgt', E'8a1ba67d-29a3-472d-9d8c-beffb14c48ce', E'b1c9395b-c045-4e0b-9b33-effa892d923d', NULL, E'2020-06-06 20:10:33', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'd7509c04-9956-459d-a111-0f379be60ebd', E'maxkey_mgt', E'f2f7f1bb-245c-4f22-bf8e-9d9f6e30b699', E'd9abaad9-a18b-4042-bdf5-3c221a4001ee', NULL, E'2020-05-09 23:33:04', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'd7b6257d-a883-4dd8-9d30-d36b989a3d37', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'4de2475d-2a31-4178-af34-12eb39248d1d', NULL, E'2020-07-19 09:59:21', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'd8abd4f5-d850-49f2-8eca-2a89e83d18c9', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'7452d560-0bc0-4bda-b2eb-d9dc7432d973', E'e238e0d1-b3db-472f-b0bf-38d889ba2df3', NULL, E'2020-07-19 09:59:14', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'd8adcf9f-adac-4f13-9e3d-fdcde5644c10', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'7452d560-0bc0-4bda-b2eb-d9dc7432d973', E'1824404a-5979-40f3-9d0e-2c1196209afb', NULL, E'2020-07-19 09:59:14', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'da570233-ef70-4485-8809-1b608e06b5ea', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'c031c924-ee84-4719-843f-493409181440', NULL, E'2020-07-19 09:59:21', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'da63850f-c13b-47d4-b954-9a4040c2a08d', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'c9991957-2579-4529-86d6-ea386e37c27a', NULL, E'2020-07-19 00:55:45', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'dc41aeda-7cb6-423f-9ab1-e2dd7bd892d5', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'dff01736-64e9-42ef-92bd-cda2ca91044f', E'ab715383-8fa5-4225-b0a2-ab01991b98e7', NULL, E'2020-07-19 10:01:26', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'dc9ea7ea-c0cf-4cac-97f1-691a13171180', E'maxkey_mgt', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'd9abaad9-a18b-4042-bdf5-3c221a4001ee', NULL, E'2020-04-29 20:17:41', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'dd1d60b6-9343-4e3d-b6bb-fc5f6f450365', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'8aca327e-033e-4867-b991-6fb9303f5aaa', NULL, E'2020-07-19 09:59:21', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'ddd5a5d6-49e0-46af-ac37-8a350d8f96a3', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'7452d560-0bc0-4bda-b2eb-d9dc7432d973', E'c9991957-2579-4529-86d6-ea386e37c27a', NULL, E'2020-07-19 09:59:14', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'e17a39e1-e91a-4974-a24a-26d27d55ad61', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'8a1ba67d-29a3-472d-9d8c-beffb14c48ce', E'1824404a-5979-40f3-9d0e-2c1196209afb', NULL, E'2020-07-19 10:00:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'e3f0d780-4d75-463e-9f3e-359ec7d7c9fb', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'dff01736-64e9-42ef-92bd-cda2ca91044f', E'e238e0d1-b3db-472f-b0bf-38d889ba2df3', NULL, E'2020-07-19 10:01:26', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'e4507339-6b5b-49af-afe4-709469ec7417', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'7452d560-0bc0-4bda-b2eb-d9dc7432d973', E'04ee2f33-3ced-4c23-992c-5c85b03dbc20', NULL, E'2020-07-19 09:59:14', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'e4d5c79e-5169-4160-a73f-ee0ffc77c77a', E'maxkey_mgt', E'8a1ba67d-29a3-472d-9d8c-beffb14c48ce', E'd9abaad9-a18b-4042-bdf5-3c221a4001ee', NULL, E'2020-06-06 20:10:33', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'e5a6e4bc-ae51-4e97-9778-4236e996b2b2', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'8a1ba67d-29a3-472d-9d8c-beffb14c48ce', E'4d7cb056-7c3f-44b5-8be6-98a088b8d09f', NULL, E'2020-07-19 10:00:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'e5fec4a2-7a80-4008-801f-4e1fd2f9af60', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'8a1ba67d-29a3-472d-9d8c-beffb14c48ce', E'463da0ad-55f2-486a-a01f-66b44a2ba18d', NULL, E'2020-07-19 10:00:34', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'e6d5ed80-42e5-4b21-8ae4-2ae54a53f0df', E'maxkey_mgt', E'dff01736-64e9-42ef-92bd-cda2ca91044f', E'cc121e8d-74f9-4d90-8b34-5d7bc34ca287', NULL, E'2020-05-10 21:43:37', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'e8efbf5a-50fb-4360-bb2c-96ecf502cd07', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'a2b1968e-78ab-46f6-96b2-7b6bab334218', NULL, E'2020-07-19 00:55:45', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'ed1383ed-f33a-4d20-ba12-2e13ac09c37a', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'3b795490-4a46-4122-b656-861f871725c3', NULL, E'2020-07-19 00:55:45', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'ed91bce8-5897-4222-82d9-8ab1771c2f44', E'maxkey_mgt', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'cc121e8d-74f9-4d90-8b34-5d7bc34ca287', NULL, E'2020-04-30 12:16:07', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'f1012ecf-905a-4b48-bb8a-ab89c3fed9fc', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'fcbc7a33-ad60-4d63-9b14-9b41120bdb49', NULL, E'2020-07-19 09:59:21', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'f113a973-8c22-4ebf-b374-d51bca0accfc', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'f2f7f1bb-245c-4f22-bf8e-9d9f6e30b699', E'ab6c11c9-7aa8-4428-beb2-f1ab77e8796e', NULL, E'2020-07-19 10:01:59', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'f13dfb9f-e28f-4d18-a4c1-18c7e0f5768c', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'32ed9486-f002-4ee9-8d91-97b6b5a3bada', NULL, E'2020-07-19 00:55:45', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'f3da91ac-dd78-4109-b78d-bfde8ddd347c', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'4de2475d-2a31-4178-af34-12eb39248d1d', NULL, E'2020-07-19 00:55:45', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'f42a8e09-b073-4916-8819-19ea8301a8f6', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'7452d560-0bc0-4bda-b2eb-d9dc7432d973', E'4de2475d-2a31-4178-af34-12eb39248d1d', NULL, E'2020-07-19 09:59:14', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'f4b1fa0b-9efa-4b2e-8a84-8ebbb897ec40', E'maxkey_mgt', E'f2f7f1bb-245c-4f22-bf8e-9d9f6e30b699', E'c4ff1146-e1f3-4219-8191-d5010b36c153', NULL, E'2020-05-09 23:33:04', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'f4c3bac6-ae0e-41ac-bd90-259cc92b4e7b', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'913f7a47-8cdc-4f5f-bc99-1f580f86a63e', NULL, E'2020-07-19 09:59:21', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'f6889ca3-8e7f-4e51-ae2c-4003f76fa325', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'e0d12156-63f4-4142-9dff-91342149262b', E'8aca327e-033e-4867-b991-6fb9303f5aaa', NULL, E'2020-07-19 10:01:40', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'f7381f4c-1d2a-44c9-8661-2497e4d37afa', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'359520ca-6699-45cd-b010-b288c9f1b835', E'3b795490-4a46-4122-b656-861f871725c3', NULL, E'2020-07-19 09:59:35', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'f83f5f91-5284-4fba-81e4-a7cb4bc6d16f', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'463da0ad-55f2-486a-a01f-66b44a2ba18d', NULL, E'2020-07-19 00:55:45', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'f8acc25f-316c-4ef8-8b4f-826233c89f30', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'f8091914-e67c-4377-a68e-0798b31f33bb', NULL, E'2020-07-19 09:59:21', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'fc6e68f2-675e-4f43-a2bc-df3a6831d74b', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'3b795490-4a46-4122-b656-861f871725c3', NULL, E'2020-07-19 09:59:21', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'fd06dbb0-7abb-4168-ac63-7410a77c7fff', E'3a93e28d-558d-4dc7-a3f2-9bf5255a1372', E'0556ac76-e6ce-46a6-8655-774ffa935bbc', E'c031c924-ee84-4719-843f-493409181440', NULL, E'2020-07-19 00:55:45', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900187512813649921', E'622227747938373638', NULL, E'fcbc7a33-ad60-4d63-9b14-9b41120bdb49', NULL, E'2023-09-15 22:24:53', 1, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900187512813649922', E'622227747938373638', NULL, E'f44a0273-ba7c-4301-b84f-c9ba9f199cda', NULL, E'2023-09-15 22:24:53', 1, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900187512813649923', E'622227747938373638', NULL, E'ab715383-8fa5-4225-b0a2-ab01991b98e7', NULL, E'2023-09-15 22:24:53', 1, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900187512813649924', E'622227747938373638', NULL, E'237e3cce-7cb7-4646-bc1a-6ca941931b5c', NULL, E'2023-09-15 22:24:53', 1, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900187512813649925', E'622227747938373638', NULL, E'1be7c248-6682-44ff-b688-4310d2e9be8a', NULL, E'2023-09-15 22:24:53', 1, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900187512813649926', E'622227747938373638', NULL, E'4d7cb056-7c3f-44b5-8be6-98a088b8d09f', NULL, E'2023-09-15 22:24:53', 1, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900187512813649927', E'622227747938373638', NULL, E'e238e0d1-b3db-472f-b0bf-38d889ba2df3', NULL, E'2023-09-15 22:24:53', 1, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900187512813649928', E'622227747938373638', NULL, E'70b2522b-e943-4d8e-860f-7c5ae7d9569f', NULL, E'2023-09-15 22:24:53', 1, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900187512813649929', E'622227747938373638', NULL, E'3b795490-4a46-4122-b656-861f871725c3', NULL, E'2023-09-15 22:24:53', 1, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900187512813649930', E'622227747938373638', NULL, E'a2b1968e-78ab-46f6-96b2-7b6bab334218', NULL, E'2023-09-15 22:24:53', 1, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900187512813649931', E'622227747938373638', NULL, E'8aca327e-033e-4867-b991-6fb9303f5aaa', NULL, E'2023-09-15 22:24:53', 1, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900187512813649932', E'622227747938373638', NULL, E'80a7a954-7dfa-454b-b4ed-3f52feeef8a3', NULL, E'2023-09-15 22:24:53', 1, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900187512813649933', E'622227747938373638', NULL, E'463da0ad-55f2-486a-a01f-66b44a2ba18d', NULL, E'2023-09-15 22:24:53', 1, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900187512813649934', E'622227747938373638', NULL, E'27e7471a-ba2c-4dde-9228-c804f096d19d', NULL, E'2023-09-15 22:24:53', 1, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900187992168071169', E'622227747938373638', NULL, E'75b21762-08c9-4e37-bf62-5e762339e159', NULL, E'2023-09-15 22:26:47', 1, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900187992168071170', E'622227747938373638', NULL, E'4de2475d-2a31-4178-af34-12eb39248d1d', NULL, E'2023-09-15 22:26:47', 1, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900187992168071171', E'622227747938373638', NULL, E'32ed9486-f002-4ee9-8d91-97b6b5a3bada', NULL, E'2023-09-15 22:26:47', 1, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900187992168071172', E'622227747938373638', NULL, E'6536e3f3-284d-4156-807f-bdc7caf46c64', NULL, E'2023-09-15 22:26:47', 1, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900189653196341249', E'622227747938373638', E'622178881788444672', E'a2b1968e-78ab-46f6-96b2-7b6bab334218', NULL, E'2023-09-15 22:33:23', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900189653196341250', E'622227747938373638', E'622178881788444672', E'8aca327e-033e-4867-b991-6fb9303f5aaa', NULL, E'2023-09-15 22:33:23', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900189653196341251', E'622227747938373638', E'622178881788444672', E'80a7a954-7dfa-454b-b4ed-3f52feeef8a3', NULL, E'2023-09-15 22:33:23', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900189653196341252', E'622227747938373638', E'622178881788444672', E'463da0ad-55f2-486a-a01f-66b44a2ba18d', NULL, E'2023-09-15 22:33:23', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900189653196341253', E'622227747938373638', E'622178881788444672', E'27e7471a-ba2c-4dde-9228-c804f096d19d', NULL, E'2023-09-15 22:33:23', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900189653196341254', E'622227747938373638', E'622178881788444672', E'ab6c11c9-7aa8-4428-beb2-f1ab77e8796e', NULL, E'2023-09-15 22:33:23', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900189653196341255', E'622227747938373638', E'622178881788444672', E'7829374f-4503-4738-b661-72c2efb6d640', NULL, E'2023-09-15 22:33:23', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900189653196341256', E'622227747938373638', E'622178881788444672', E'231c6a4b-a903-47ed-8110-4664371e326e', NULL, E'2023-09-15 22:33:23', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900189653196341257', E'622227747938373638', E'622178881788444672', E'1824404a-5979-40f3-9d0e-2c1196209afb', NULL, E'2023-09-15 22:33:23', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900189653196341258', E'622227747938373638', E'622178881788444672', E'0f92f830-8a3c-4e0c-b40a-0645bd96cb3c', NULL, E'2023-09-15 22:33:23', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900189653196341259', E'622227747938373638', E'622178881788444672', E'8c3da816-882c-466d-aec2-92a02cbbe5d7', NULL, E'2023-09-15 22:33:23', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900189653196341260', E'622227747938373638', E'622178881788444672', E'876075528325431296', NULL, E'2023-09-15 22:33:23', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900189653196341261', E'622227747938373638', E'622178881788444672', E'876073879422894080', NULL, E'2023-09-15 22:33:23', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900189653196341262', E'622227747938373638', E'622178881788444672', E'18a82e89-56f7-4538-975f-7de500e5e15e', NULL, E'2023-09-15 22:33:23', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900189653196341263', E'622227747938373638', E'622178881788444672', E'04ee2f33-3ced-4c23-992c-5c85b03dbc20', NULL, E'2023-09-15 22:33:23', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900189713774673921', E'622227747938373638', E'622178518125510656', E'a2b1968e-78ab-46f6-96b2-7b6bab334218', NULL, E'2023-09-15 22:33:38', 1, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900189713774673922', E'622227747938373638', E'622178518125510656', E'8aca327e-033e-4867-b991-6fb9303f5aaa', NULL, E'2023-09-15 22:33:38', 1, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900189713774673923', E'622227747938373638', E'622178518125510656', E'80a7a954-7dfa-454b-b4ed-3f52feeef8a3', NULL, E'2023-09-15 22:33:38', 1, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900189713774673924', E'622227747938373638', E'622178518125510656', E'463da0ad-55f2-486a-a01f-66b44a2ba18d', NULL, E'2023-09-15 22:33:38', 1, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900189713774673925', E'622227747938373638', E'622178518125510656', E'27e7471a-ba2c-4dde-9228-c804f096d19d', NULL, E'2023-09-15 22:33:38', 1, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900189713774673926', E'622227747938373638', E'622178518125510656', E'ab6c11c9-7aa8-4428-beb2-f1ab77e8796e', NULL, E'2023-09-15 22:33:38', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900189713774673927', E'622227747938373638', E'622178518125510656', E'7829374f-4503-4738-b661-72c2efb6d640', NULL, E'2023-09-15 22:33:38', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900189713774673928', E'622227747938373638', E'622178518125510656', E'231c6a4b-a903-47ed-8110-4664371e326e', NULL, E'2023-09-15 22:33:38', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900189713774673929', E'622227747938373638', E'622178518125510656', E'1824404a-5979-40f3-9d0e-2c1196209afb', NULL, E'2023-09-15 22:33:38', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900189713774673930', E'622227747938373638', E'622178518125510656', E'0f92f830-8a3c-4e0c-b40a-0645bd96cb3c', NULL, E'2023-09-15 22:33:38', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900190596029743104', E'622227747938373638', E'622179552155664384', E'c031c924-ee84-4719-843f-493409181440', NULL, E'2023-09-15 22:37:08', 1, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900190596029743105', E'622227747938373638', E'622179552155664384', E'913f7a47-8cdc-4f5f-bc99-1f580f86a63e', NULL, E'2023-09-15 22:37:08', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900190596029743106', E'622227747938373638', E'622179552155664384', E'6536e3f3-284d-4156-807f-bdc7caf46c64', NULL, E'2023-09-15 22:37:08', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900190596029743107', E'622227747938373638', E'622179552155664384', E'4d7cb056-7c3f-44b5-8be6-98a088b8d09f', NULL, E'2023-09-15 22:37:08', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900190596029743108', E'622227747938373638', E'622179552155664384', E'3b795490-4a46-4122-b656-861f871725c3', NULL, E'2023-09-15 22:37:08', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900190596029743109', E'622227747938373638', E'622179552155664384', E'27e7471a-ba2c-4dde-9228-c804f096d19d', NULL, E'2023-09-15 22:37:08', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900190596029743110', E'622227747938373638', E'622179552155664384', E'0f92f830-8a3c-4e0c-b40a-0645bd96cb3c', NULL, E'2023-09-15 22:37:08', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900190596029743111', E'622227747938373638', E'622179552155664384', E'04ee2f33-3ced-4c23-992c-5c85b03dbc20', NULL, E'2023-09-15 22:37:08', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900191080555741185', E'622227747938373638', E'622178881788444672', E'e238e0d1-b3db-472f-b0bf-38d889ba2df3', NULL, E'2023-09-15 22:39:03', 1, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900191080555741186', E'622227747938373638', E'622178881788444672', E'70b2522b-e943-4d8e-860f-7c5ae7d9569f', NULL, E'2023-09-15 22:39:03', 1, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'900191080555741187', E'622227747938373638', E'622178881788444672', E'3b795490-4a46-4122-b656-861f871725c3', NULL, E'2023-09-15 22:39:03', 1, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'1012728950486466561', E'622227747938373638', E'622178518125510656', E'8c3da816-882c-466d-aec2-92a02cbbe5d7', NULL, E'2024-07-22 11:44:23', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'1012728950486466562', E'622227747938373638', E'622178518125510656', E'876075528325431296', NULL, E'2024-07-22 11:44:23', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'1012728950486466563', E'622227747938373638', E'622178518125510656', E'876073879422894080', NULL, E'2024-07-22 11:44:23', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'1012728950486466564', E'622227747938373638', E'622178518125510656', E'18a82e89-56f7-4538-975f-7de500e5e15e', NULL, E'2024-07-22 11:44:23', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'1012728950486466565', E'622227747938373638', E'622178518125510656', E'04ee2f33-3ced-4c23-992c-5c85b03dbc20', NULL, E'2024-07-22 11:44:23', 9, E'1');
INSERT INTO mxk_permission (id, appid, groupid, resourceid, createdby, createddate, status, instid) VALUES (E'1113530875770830850', E'622227747938373638', E'622179552155664384', E'f8091914-e67c-4377-a68e-0798b31f33bb', NULL, E'2025-04-26 15:35:14', 1, E'1');
INSERT INTO mxk_permission_role (id, appid, roleid, resourceid, createdby, createddate, status, instid) VALUES (E'1012782724181655552', E'622227747938373638', E'1012782708134248448', E'c031c924-ee84-4719-843f-493409181440', E'1', E'2024-07-22 15:18:03', 1, E'1');
INSERT INTO mxk_permission_role (id, appid, roleid, resourceid, createdby, createddate, status, instid) VALUES (E'1012782724181655553', E'622227747938373638', E'1012782708134248448', E'913f7a47-8cdc-4f5f-bc99-1f580f86a63e', E'1', E'2024-07-22 15:18:03', 1, E'1');
INSERT INTO mxk_permission_role (id, appid, roleid, resourceid, createdby, createddate, status, instid) VALUES (E'1012782724181655554', E'622227747938373638', E'1012782708134248448', E'6536e3f3-284d-4156-807f-bdc7caf46c64', E'1', E'2024-07-22 15:18:03', 1, E'1');
INSERT INTO mxk_permission_role (id, appid, roleid, resourceid, createdby, createddate, status, instid) VALUES (E'1012782724181655555', E'622227747938373638', E'1012782708134248448', E'4d7cb056-7c3f-44b5-8be6-98a088b8d09f', E'1', E'2024-07-22 15:18:03', 1, E'1');
INSERT INTO mxk_permission_role (id, appid, roleid, resourceid, createdby, createddate, status, instid) VALUES (E'1012782724181655556', E'622227747938373638', E'1012782708134248448', E'3b795490-4a46-4122-b656-861f871725c3', E'1', E'2024-07-22 15:18:03', 1, E'1');
INSERT INTO mxk_permission_role (id, appid, roleid, resourceid, createdby, createddate, status, instid) VALUES (E'1012782724181655557', E'622227747938373638', E'1012782708134248448', E'27e7471a-ba2c-4dde-9228-c804f096d19d', E'1', E'2024-07-22 15:18:03', 1, E'1');
INSERT INTO mxk_permission_role (id, appid, roleid, resourceid, createdby, createddate, status, instid) VALUES (E'1012782724181655558', E'622227747938373638', E'1012782708134248448', E'0f92f830-8a3c-4e0c-b40a-0645bd96cb3c', E'1', E'2024-07-22 15:18:03', 1, E'1');
INSERT INTO mxk_permission_role (id, appid, roleid, resourceid, createdby, createddate, status, instid) VALUES (E'1012782724181655559', E'622227747938373638', E'1012782708134248448', E'04ee2f33-3ced-4c23-992c-5c85b03dbc20', E'1', E'2024-07-22 15:18:03', 9, E'1');
INSERT INTO mxk_permission_role (id, appid, roleid, resourceid, createdby, createddate, status, instid) VALUES (E'1012782750870011905', E'622227747938373638', E'1012782708134248448', E'f8091914-e67c-4377-a68e-0798b31f33bb', E'1', E'2024-07-22 15:18:10', 1, E'1');
INSERT INTO mxk_permission_role (id, appid, roleid, resourceid, createdby, createddate, status, instid) VALUES (E'1012782750870011906', E'622227747938373638', E'1012782708134248448', E'c9991957-2579-4529-86d6-ea386e37c27a', E'1', E'2024-07-22 15:18:10', 1, E'1');
INSERT INTO mxk_permission_role (id, appid, roleid, resourceid, createdby, createddate, status, instid) VALUES (E'1012782750870011908', E'622227747938373638', E'1012782708134248448', E'fddc2287-0628-489f-807d-7bcb49285632', E'1', E'2024-07-22 15:18:10', 1, E'1');
INSERT INTO mxk_permission_role (id, appid, roleid, resourceid, createdby, createddate, status, instid) VALUES (E'1012782750870011910', E'622227747938373638', E'1012782708134248448', E'75b21762-08c9-4e37-bf62-5e762339e159', E'1', E'2024-07-22 15:18:10', 1, E'1');
INSERT INTO mxk_permission_role (id, appid, roleid, resourceid, createdby, createddate, status, instid) VALUES (E'1012782750870011911', E'622227747938373638', E'1012782708134248448', E'4de2475d-2a31-4178-af34-12eb39248d1d', E'1', E'2024-07-22 15:18:10', 1, E'1');
INSERT INTO mxk_permission_role (id, appid, roleid, resourceid, createdby, createddate, status, instid) VALUES (E'1012782750870011912', E'622227747938373638', E'1012782708134248448', E'32ed9486-f002-4ee9-8d91-97b6b5a3bada', E'1', E'2024-07-22 15:18:10', 1, E'1');
INSERT INTO mxk_permission_role (id, appid, roleid, resourceid, createdby, createddate, status, instid) VALUES (E'1012782750870011914', E'622227747938373638', E'1012782708134248448', E'fcbc7a33-ad60-4d63-9b14-9b41120bdb49', E'1', E'2024-07-22 15:18:10', 1, E'1');
INSERT INTO mxk_permission_role (id, appid, roleid, resourceid, createdby, createddate, status, instid) VALUES (E'1012782750870011915', E'622227747938373638', E'1012782708134248448', E'f44a0273-ba7c-4301-b84f-c9ba9f199cda', E'1', E'2024-07-22 15:18:10', 1, E'1');
INSERT INTO mxk_permission_role (id, appid, roleid, resourceid, createdby, createddate, status, instid) VALUES (E'1012782750870011916', E'622227747938373638', E'1012782708134248448', E'ab715383-8fa5-4225-b0a2-ab01991b98e7', E'1', E'2024-07-22 15:18:10', 1, E'1');
INSERT INTO mxk_permission_role (id, appid, roleid, resourceid, createdby, createddate, status, instid) VALUES (E'1012782750870011917', E'622227747938373638', E'1012782708134248448', E'237e3cce-7cb7-4646-bc1a-6ca941931b5c', E'1', E'2024-07-22 15:18:10', 1, E'1');
INSERT INTO mxk_permission_role (id, appid, roleid, resourceid, createdby, createddate, status, instid) VALUES (E'1012782750870011918', E'622227747938373638', E'1012782708134248448', E'1be7c248-6682-44ff-b688-4310d2e9be8a', E'1', E'2024-07-22 15:18:10', 1, E'1');
INSERT INTO mxk_permission_role (id, appid, roleid, resourceid, createdby, createddate, status, instid) VALUES (E'1012782750870011920', E'622227747938373638', E'1012782708134248448', E'e238e0d1-b3db-472f-b0bf-38d889ba2df3', E'1', E'2024-07-22 15:18:10', 1, E'1');
INSERT INTO mxk_permission_role (id, appid, roleid, resourceid, createdby, createddate, status, instid) VALUES (E'1012782750870011921', E'622227747938373638', E'1012782708134248448', E'70b2522b-e943-4d8e-860f-7c5ae7d9569f', E'1', E'2024-07-22 15:18:10', 1, E'1');
INSERT INTO mxk_permission_role (id, appid, roleid, resourceid, createdby, createddate, status, instid) VALUES (E'1012782750870011923', E'622227747938373638', E'1012782708134248448', E'a2b1968e-78ab-46f6-96b2-7b6bab334218', E'1', E'2024-07-22 15:18:10', 1, E'1');
INSERT INTO mxk_permission_role (id, appid, roleid, resourceid, createdby, createddate, status, instid) VALUES (E'1012782750870011924', E'622227747938373638', E'1012782708134248448', E'8aca327e-033e-4867-b991-6fb9303f5aaa', E'1', E'2024-07-22 15:18:10', 1, E'1');
INSERT INTO mxk_permission_role (id, appid, roleid, resourceid, createdby, createddate, status, instid) VALUES (E'1012782750870011925', E'622227747938373638', E'1012782708134248448', E'80a7a954-7dfa-454b-b4ed-3f52feeef8a3', E'1', E'2024-07-22 15:18:10', 1, E'1');
INSERT INTO mxk_permission_role (id, appid, roleid, resourceid, createdby, createddate, status, instid) VALUES (E'1012782750870011926', E'622227747938373638', E'1012782708134248448', E'463da0ad-55f2-486a-a01f-66b44a2ba18d', E'1', E'2024-07-22 15:18:10', 1, E'1');
INSERT INTO mxk_permission_role (id, appid, roleid, resourceid, createdby, createddate, status, instid) VALUES (E'1012782750870011928', E'622227747938373638', E'1012782708134248448', E'ab6c11c9-7aa8-4428-beb2-f1ab77e8796e', E'1', E'2024-07-22 15:18:10', 1, E'1');
INSERT INTO mxk_permission_role (id, appid, roleid, resourceid, createdby, createddate, status, instid) VALUES (E'1012782750870011929', E'622227747938373638', E'1012782708134248448', E'7829374f-4503-4738-b661-72c2efb6d640', E'1', E'2024-07-22 15:18:10', 1, E'1');
INSERT INTO mxk_permission_role (id, appid, roleid, resourceid, createdby, createddate, status, instid) VALUES (E'1012782750870011930', E'622227747938373638', E'1012782708134248448', E'231c6a4b-a903-47ed-8110-4664371e326e', E'1', E'2024-07-22 15:18:10', 1, E'1');
INSERT INTO mxk_permission_role (id, appid, roleid, resourceid, createdby, createddate, status, instid) VALUES (E'1012782750870011931', E'622227747938373638', E'1012782708134248448', E'1824404a-5979-40f3-9d0e-2c1196209afb', E'1', E'2024-07-22 15:18:10', 1, E'1');
INSERT INTO mxk_permission_role (id, appid, roleid, resourceid, createdby, createddate, status, instid) VALUES (E'1012797637067276289', E'622227747938373638', E'1012783210737696768', E'75b21762-08c9-4e37-bf62-5e762339e159', E'1', E'2024-07-22 16:17:19', 9, E'1');
INSERT INTO mxk_permission_role (id, appid, roleid, resourceid, createdby, createddate, status, instid) VALUES (E'1012797637067276290', E'622227747938373638', E'1012783210737696768', E'4de2475d-2a31-4178-af34-12eb39248d1d', E'1', E'2024-07-22 16:17:19', 1, E'1');
INSERT INTO mxk_permission_role (id, appid, roleid, resourceid, createdby, createddate, status, instid) VALUES (E'1012797637067276291', E'622227747938373638', E'1012783210737696768', E'32ed9486-f002-4ee9-8d91-97b6b5a3bada', E'1', E'2024-07-22 16:17:19', 1, E'1');
INSERT INTO mxk_permission_role (id, appid, roleid, resourceid, createdby, createddate, status, instid) VALUES (E'1012797637067276292', E'622227747938373638', E'1012783210737696768', E'6536e3f3-284d-4156-807f-bdc7caf46c64', E'1', E'2024-07-22 16:17:19', 1, E'1');
INSERT INTO mxk_permission_role (id, appid, roleid, resourceid, createdby, createddate, status, instid) VALUES (E'1012797653882241025', E'622227747938373638', E'1012796645571559424', E'f8091914-e67c-4377-a68e-0798b31f33bb', E'1', E'2024-07-22 16:17:23', 1, E'1');
INSERT INTO mxk_permission_role (id, appid, roleid, resourceid, createdby, createddate, status, instid) VALUES (E'1012797653882241026', E'622227747938373638', E'1012796645571559424', E'c9991957-2579-4529-86d6-ea386e37c27a', E'1', E'2024-07-22 16:17:23', 1, E'1');
INSERT INTO mxk_permission_role (id, appid, roleid, resourceid, createdby, createddate, status, instid) VALUES (E'1012797653882241027', E'622227747938373638', E'1012796645571559424', E'c031c924-ee84-4719-843f-493409181440', E'1', E'2024-07-22 16:17:23', 1, E'1');
INSERT INTO mxk_resources (id, resourcename, resourcetype, resourceurl, permission, status, description, createdby, createddate, modifiedby, modifieddate, parentid, parentname, appid, resourceaction, resourceicon, resourcestyle, sortindex, instid) VALUES (E'04ee2f33-3ced-4c23-992c-5c85b03dbc20', E'基础资料', E'MENU', E'资源地址', E'basicinfo:access', E'1', E'', NULL, NULL, NULL, NULL, E'622227747938373638', E'人力资源管理系统', E'622227747938373638', E'触发动作', E'资源图标', E'资源样式', 1, E'1');
INSERT INTO mxk_resources (id, resourcename, resourcetype, resourceurl, permission, status, description, createdby, createddate, modifiedby, modifieddate, parentid, parentname, appid, resourceaction, resourceicon, resourcestyle, sortindex, instid) VALUES (E'0f92f830-8a3c-4e0c-b40a-0645bd96cb3c', E'培训管理', E'MENU', E'培训管理', NULL, E'1', E'', NULL, NULL, NULL, NULL, E'622227747938373638', E'人力资源管理系统', E'622227747938373638', E'培训管理', E'培训管理', E'培训管理', 4, E'1');
INSERT INTO mxk_resources (id, resourcename, resourcetype, resourceurl, permission, status, description, createdby, createddate, modifiedby, modifieddate, parentid, parentname, appid, resourceaction, resourceicon, resourcestyle, sortindex, instid) VALUES (E'1824404a-5979-40f3-9d0e-2c1196209afb', E'培训流程', E'MENU', E'培训流程', NULL, E'1', E'', NULL, NULL, NULL, NULL, E'0f92f830-8a3c-4e0c-b40a-0645bd96cb3c', E'培训管理', E'622227747938373638', E'培训流程', E'培训流程', E'培训流程', 4, E'1');
INSERT INTO mxk_resources (id, resourcename, resourcetype, resourceurl, permission, status, description, createdby, createddate, modifiedby, modifieddate, parentid, parentname, appid, resourceaction, resourceicon, resourcestyle, sortindex, instid) VALUES (E'18a82e89-56f7-4538-975f-7de500e5e15e', E'社会保险', E'MENU', E'社会保险', NULL, E'1', E'', NULL, NULL, NULL, NULL, E'04ee2f33-3ced-4c23-992c-5c85b03dbc20', E'基础资料', E'622227747938373638', E'社会保险', E'社会保险', E'社会保险', 1, E'1');
INSERT INTO mxk_resources (id, resourcename, resourcetype, resourceurl, permission, status, description, createdby, createddate, modifiedby, modifieddate, parentid, parentname, appid, resourceaction, resourceicon, resourcestyle, sortindex, instid) VALUES (E'1be7c248-6682-44ff-b688-4310d2e9be8a', E'转正流程', E'MENU', E'转正流程', NULL, E'1', E'', NULL, NULL, NULL, NULL, E'4d7cb056-7c3f-44b5-8be6-98a088b8d09f', E'人事管理', E'622227747938373638', E'转正流程', E'转正流程', E'转正流程', 1, E'1');
INSERT INTO mxk_resources (id, resourcename, resourcetype, resourceurl, permission, status, description, createdby, createddate, modifiedby, modifieddate, parentid, parentname, appid, resourceaction, resourceicon, resourcestyle, sortindex, instid) VALUES (E'231c6a4b-a903-47ed-8110-4664371e326e', E'培训教材', E'MENU', E'培训教材', NULL, E'1', E'', NULL, NULL, NULL, NULL, E'0f92f830-8a3c-4e0c-b40a-0645bd96cb3c', E'培训管理', E'622227747938373638', E'培训教材', E'培训教材', E'培训教材', 1, E'1');
INSERT INTO mxk_resources (id, resourcename, resourcetype, resourceurl, permission, status, description, createdby, createddate, modifiedby, modifieddate, parentid, parentname, appid, resourceaction, resourceicon, resourcestyle, sortindex, instid) VALUES (E'237e3cce-7cb7-4646-bc1a-6ca941931b5c', E'人员档案', E'MENU', E'人员档案', NULL, E'1', E'', NULL, NULL, NULL, NULL, E'4d7cb056-7c3f-44b5-8be6-98a088b8d09f', E'人事管理', E'622227747938373638', E'人员档案', E'人员档案', E'人员档案', 2, E'1');
INSERT INTO mxk_resources (id, resourcename, resourcetype, resourceurl, permission, status, description, createdby, createddate, modifiedby, modifieddate, parentid, parentname, appid, resourceaction, resourceicon, resourcestyle, sortindex, instid) VALUES (E'27e7471a-ba2c-4dde-9228-c804f096d19d', E'薪资管理', E'MENU', E'薪资管理', NULL, E'1', E'', NULL, NULL, NULL, NULL, E'622227747938373638', E'人力资源管理系统', E'622227747938373638', E'薪资管理', E'薪资管理', E'薪资管理', 3, E'1');
INSERT INTO mxk_resources (id, resourcename, resourcetype, resourceurl, permission, status, description, createdby, createddate, modifiedby, modifieddate, parentid, parentname, appid, resourceaction, resourceicon, resourcestyle, sortindex, instid) VALUES (E'32ed9486-f002-4ee9-8d91-97b6b5a3bada', E'商业保险', E'MENU', E'商业保险', NULL, E'1', E'', NULL, NULL, NULL, NULL, E'6536e3f3-284d-4156-807f-bdc7caf46c64', E'福利管理', E'622227747938373638', E'商业保险', E'商业保险', E'商业保险', 3, E'1');
INSERT INTO mxk_resources (id, resourcename, resourcetype, resourceurl, permission, status, description, createdby, createddate, modifiedby, modifieddate, parentid, parentname, appid, resourceaction, resourceicon, resourcestyle, sortindex, instid) VALUES (E'3b795490-4a46-4122-b656-861f871725c3', E'招聘管理', E'MENU', E'招聘管理', NULL, E'1', E'', NULL, NULL, NULL, NULL, E'622227747938373638', E'人力资源管理系统', E'622227747938373638', E'招聘管理', E'招聘管理', E'招聘管理', 2, E'1');
INSERT INTO mxk_resources (id, resourcename, resourcetype, resourceurl, permission, status, description, createdby, createddate, modifiedby, modifieddate, parentid, parentname, appid, resourceaction, resourceicon, resourcestyle, sortindex, instid) VALUES (E'463da0ad-55f2-486a-a01f-66b44a2ba18d', E'工资结果', E'MENU', E'工资结果', NULL, E'1', E'', NULL, NULL, NULL, NULL, E'27e7471a-ba2c-4dde-9228-c804f096d19d', E'薪资管理', E'622227747938373638', E'工资结果', E'工资结果', E'工资结果', 4, E'1');
INSERT INTO mxk_resources (id, resourcename, resourcetype, resourceurl, permission, status, description, createdby, createddate, modifiedby, modifieddate, parentid, parentname, appid, resourceaction, resourceicon, resourcestyle, sortindex, instid) VALUES (E'4d7cb056-7c3f-44b5-8be6-98a088b8d09f', E'人事管理', E'MENU', E'人事管理', NULL, E'1', E'', NULL, NULL, NULL, NULL, E'622227747938373638', E'人力资源管理系统', E'622227747938373638', E'人事管理', E'人事管理', E'人事管理', 6, E'1');
INSERT INTO mxk_resources (id, resourcename, resourcetype, resourceurl, permission, status, description, createdby, createddate, modifiedby, modifieddate, parentid, parentname, appid, resourceaction, resourceicon, resourcestyle, sortindex, instid) VALUES (E'4de2475d-2a31-4178-af34-12eb39248d1d', E'社保方案', E'MENU', E'社保方案', NULL, E'1', E'', NULL, NULL, NULL, NULL, E'6536e3f3-284d-4156-807f-bdc7caf46c64', E'福利管理', E'622227747938373638', E'社保方案', E'社保方案', E'社保方案', 1, E'1');
INSERT INTO mxk_resources (id, resourcename, resourcetype, resourceurl, permission, status, description, createdby, createddate, modifiedby, modifieddate, parentid, parentname, appid, resourceaction, resourceicon, resourcestyle, sortindex, instid) VALUES (E'6536e3f3-284d-4156-807f-bdc7caf46c64', E'福利管理', E'MENU', E'福利管理', NULL, E'1', E'', NULL, NULL, NULL, NULL, E'622227747938373638', E'人力资源管理系统', E'622227747938373638', E'福利管理', E'福利管理', E'福利管理', 5, E'1');
INSERT INTO mxk_resources (id, resourcename, resourcetype, resourceurl, permission, status, description, createdby, createddate, modifiedby, modifieddate, parentid, parentname, appid, resourceaction, resourceicon, resourcestyle, sortindex, instid) VALUES (E'70b2522b-e943-4d8e-860f-7c5ae7d9569f', E'面试管理', E'MENU', E'面试管理', NULL, E'1', E'', NULL, NULL, NULL, NULL, E'3b795490-4a46-4122-b656-861f871725c3', E'招聘管理', E'622227747938373638', E'面试管理', E'面试管理', E'面试管理', 2, E'1');
INSERT INTO mxk_resources (id, resourcename, resourcetype, resourceurl, permission, status, description, createdby, createddate, modifiedby, modifieddate, parentid, parentname, appid, resourceaction, resourceicon, resourcestyle, sortindex, instid) VALUES (E'75b21762-08c9-4e37-bf62-5e762339e159', E'公积金方案', E'MENU', E'公积金方案', NULL, E'1', E'', NULL, NULL, NULL, NULL, E'6536e3f3-284d-4156-807f-bdc7caf46c64', E'福利管理', E'622227747938373638', E'公积金方案', E'公积金方案', E'公积金方案', 2, E'1');
INSERT INTO mxk_resources (id, resourcename, resourcetype, resourceurl, permission, status, description, createdby, createddate, modifiedby, modifieddate, parentid, parentname, appid, resourceaction, resourceicon, resourcestyle, sortindex, instid) VALUES (E'7829374f-4503-4738-b661-72c2efb6d640', E'培训讲师', E'MENU', E'培训讲师', NULL, E'1', E'', NULL, NULL, NULL, NULL, E'0f92f830-8a3c-4e0c-b40a-0645bd96cb3c', E'培训管理', E'622227747938373638', E'培训讲师', E'培训讲师', E'培训讲师', 2, E'1');
INSERT INTO mxk_resources (id, resourcename, resourcetype, resourceurl, permission, status, description, createdby, createddate, modifiedby, modifieddate, parentid, parentname, appid, resourceaction, resourceicon, resourcestyle, sortindex, instid) VALUES (E'80a7a954-7dfa-454b-b4ed-3f52feeef8a3', E'工资造表', E'MENU', E'工资造表', NULL, E'1', E'', NULL, NULL, NULL, NULL, E'27e7471a-ba2c-4dde-9228-c804f096d19d', E'薪资管理', E'622227747938373638', E'工资造表', E'工资造表', E'工资造表', 3, E'1');
INSERT INTO mxk_resources (id, resourcename, resourcetype, resourceurl, permission, status, description, createdby, createddate, modifiedby, modifieddate, parentid, parentname, appid, resourceaction, resourceicon, resourcestyle, sortindex, instid) VALUES (E'876073879422894080', E'2222', E'PAGE', NULL, NULL, E'1', NULL, NULL, NULL, NULL, NULL, E'04ee2f33-3ced-4c23-992c-5c85b03dbc20', E'基础资料', NULL, NULL, NULL, NULL, 1, E'1');
INSERT INTO mxk_resources (id, resourcename, resourcetype, resourceurl, permission, status, description, createdby, createddate, modifiedby, modifieddate, parentid, parentname, appid, resourceaction, resourceicon, resourcestyle, sortindex, instid) VALUES (E'876075528325431296', E'111', E'PAGE', NULL, NULL, E'1', NULL, NULL, NULL, NULL, NULL, E'04ee2f33-3ced-4c23-992c-5c85b03dbc20', E'基础资料', E'622227747938373638', NULL, NULL, NULL, 1, E'1');
INSERT INTO mxk_resources (id, resourcename, resourcetype, resourceurl, permission, status, description, createdby, createddate, modifiedby, modifieddate, parentid, parentname, appid, resourceaction, resourceicon, resourcestyle, sortindex, instid) VALUES (E'8aca327e-033e-4867-b991-6fb9303f5aaa', E'工资方案', E'MENU', E'工资方案', NULL, E'1', E'', NULL, NULL, NULL, NULL, E'27e7471a-ba2c-4dde-9228-c804f096d19d', E'薪资管理', E'622227747938373638', E'工资方案', E'工资方案', E'工资方案', 1, E'1');
INSERT INTO mxk_resources (id, resourcename, resourcetype, resourceurl, permission, status, description, createdby, createddate, modifiedby, modifieddate, parentid, parentname, appid, resourceaction, resourceicon, resourcestyle, sortindex, instid) VALUES (E'8c3da816-882c-466d-aec2-92a02cbbe5d7', E'公积金', E'MENU', E'公积金', NULL, E'1', E'', NULL, NULL, NULL, NULL, E'04ee2f33-3ced-4c23-992c-5c85b03dbc20', E'基础资料', E'622227747938373638', E'公积金', E'公积金', E'公积金', 2, E'1');
INSERT INTO mxk_resources (id, resourcename, resourcetype, resourceurl, permission, status, description, createdby, createddate, modifiedby, modifieddate, parentid, parentname, appid, resourceaction, resourceicon, resourcestyle, sortindex, instid) VALUES (E'913f7a47-8cdc-4f5f-bc99-1f580f86a63e', E'人事关系', E'MENU', E'人事关系', NULL, E'1', E'', NULL, NULL, NULL, NULL, E'622227747938373638', E'人力资源管理系统', E'622227747938373638', E'人事关系', E'人事关系', E'人事关系', 7, E'1');
INSERT INTO mxk_resources (id, resourcename, resourcetype, resourceurl, permission, status, description, createdby, createddate, modifiedby, modifieddate, parentid, parentname, appid, resourceaction, resourceicon, resourcestyle, sortindex, instid) VALUES (E'984026610069929984', E'应用接口', E'MENU', NULL, NULL, E'1', NULL, NULL, E'2024-05-04 06:51:31', NULL, NULL, E'644220607860310016', E'OAUTH2.1', E'644220607860310016', NULL, NULL, NULL, 1, E'1');
INSERT INTO mxk_resources (id, resourcename, resourcetype, resourceurl, permission, status, description, createdby, createddate, modifiedby, modifieddate, parentid, parentname, appid, resourceaction, resourceicon, resourcestyle, sortindex, instid) VALUES (E'a2b1968e-78ab-46f6-96b2-7b6bab334218', E'工资项目', E'MENU', E'工资项目', NULL, E'1', E'', NULL, NULL, NULL, NULL, E'27e7471a-ba2c-4dde-9228-c804f096d19d', E'薪资管理', E'622227747938373638', E'工资项目', E'工资项目', E'工资项目', 2, E'1');
INSERT INTO mxk_resources (id, resourcename, resourcetype, resourceurl, permission, status, description, createdby, createddate, modifiedby, modifieddate, parentid, parentname, appid, resourceaction, resourceicon, resourcestyle, sortindex, instid) VALUES (E'ab6c11c9-7aa8-4428-beb2-f1ab77e8796e', E'培训机构', E'MENU', E'培训机构', NULL, E'1', E'', NULL, NULL, NULL, NULL, E'0f92f830-8a3c-4e0c-b40a-0645bd96cb3c', E'培训管理', E'622227747938373638', E'培训机构', E'培训机构', E'培训机构', 3, E'1');
INSERT INTO mxk_resources (id, resourcename, resourcetype, resourceurl, permission, status, description, createdby, createddate, modifiedby, modifieddate, parentid, parentname, appid, resourceaction, resourceicon, resourcestyle, sortindex, instid) VALUES (E'ab715383-8fa5-4225-b0a2-ab01991b98e7', E'离职流程', E'MENU', E'离职流程', NULL, E'1', E'', NULL, NULL, NULL, NULL, E'4d7cb056-7c3f-44b5-8be6-98a088b8d09f', E'人事管理', E'622227747938373638', E'离职流程', E'离职流程', E'离职流程', 5, E'1');
INSERT INTO mxk_resources (id, resourcename, resourcetype, resourceurl, permission, status, description, createdby, createddate, modifiedby, modifieddate, parentid, parentname, appid, resourceaction, resourceicon, resourcestyle, sortindex, instid) VALUES (E'c031c924-ee84-4719-843f-493409181440', E'考勤管理', E'MENU', E'考勤管理', NULL, E'1', E'', NULL, NULL, NULL, NULL, E'622227747938373638', E'人力资源管理系统', E'622227747938373638', E'考勤管理', E'考勤管理', E'考勤管理', 8, E'1');
INSERT INTO mxk_resources (id, resourcename, resourcetype, resourceurl, permission, status, description, createdby, createddate, modifiedby, modifieddate, parentid, parentname, appid, resourceaction, resourceicon, resourcestyle, sortindex, instid) VALUES (E'c9991957-2579-4529-86d6-ea386e37c27a', E'打卡管理', E'MENU', E'打卡管理', NULL, E'1', E'', NULL, NULL, NULL, NULL, E'c031c924-ee84-4719-843f-493409181440', E'考勤管理', E'622227747938373638', E'打卡管理', E'打卡管理', E'打卡管理', 2, E'1');
INSERT INTO mxk_resources (id, resourcename, resourcetype, resourceurl, permission, status, description, createdby, createddate, modifiedby, modifieddate, parentid, parentname, appid, resourceaction, resourceicon, resourcestyle, sortindex, instid) VALUES (E'e238e0d1-b3db-472f-b0bf-38d889ba2df3', E'简历管理', E'MENU', E'简历管理', NULL, E'1', E'', NULL, NULL, NULL, NULL, E'3b795490-4a46-4122-b656-861f871725c3', E'招聘管理', E'622227747938373638', E'简历管理', E'简历管理', E'简历管理', 1, E'1');
INSERT INTO mxk_resources (id, resourcename, resourcetype, resourceurl, permission, status, description, createdby, createddate, modifiedby, modifieddate, parentid, parentname, appid, resourceaction, resourceicon, resourcestyle, sortindex, instid) VALUES (E'f44a0273-ba7c-4301-b84f-c9ba9f199cda', E'变动流程', E'MENU', E'变动流程', NULL, E'1', E'', NULL, NULL, NULL, NULL, E'4d7cb056-7c3f-44b5-8be6-98a088b8d09f', E'人事管理', E'622227747938373638', E'变动流程', E'变动流程', E'变动流程', 3, E'1');
INSERT INTO mxk_resources (id, resourcename, resourcetype, resourceurl, permission, status, description, createdby, createddate, modifiedby, modifieddate, parentid, parentname, appid, resourceaction, resourceicon, resourcestyle, sortindex, instid) VALUES (E'f8091914-e67c-4377-a68e-0798b31f33bb', E'班次设定', E'MENU', E'班次设定', NULL, E'1', E'', NULL, NULL, NULL, NULL, E'c031c924-ee84-4719-843f-493409181440', E'考勤管理', E'622227747938373638', E'班次设定', E'班次设定', E'班次设定', 1, E'1');
INSERT INTO mxk_resources (id, resourcename, resourcetype, resourceurl, permission, status, description, createdby, createddate, modifiedby, modifieddate, parentid, parentname, appid, resourceaction, resourceicon, resourcestyle, sortindex, instid) VALUES (E'fcbc7a33-ad60-4d63-9b14-9b41120bdb49', E'奖惩流程', E'MENU', E'奖惩流程', NULL, E'1', E'', NULL, NULL, NULL, NULL, E'4d7cb056-7c3f-44b5-8be6-98a088b8d09f', E'人事管理', E'622227747938373638', E'奖惩流程', E'奖惩流程', E'奖惩流程', 4, E'1');
INSERT INTO mxk_resources (id, resourcename, resourcetype, resourceurl, permission, status, description, createdby, createddate, modifiedby, modifieddate, parentid, parentname, appid, resourceaction, resourceicon, resourcestyle, sortindex, instid) VALUES (E'fddc2287-0628-489f-807d-7bcb49285632', E'保险理赔', E'MENU', E'保险理赔', NULL, E'1', E'', NULL, NULL, NULL, NULL, E'913f7a47-8cdc-4f5f-bc99-1f580f86a63e', E'人事关系', E'622227747938373638', E'保险理赔', E'保险理赔', E'保险理赔', 1, E'1');
INSERT INTO mxk_resources (id, resourcename, resourcetype, resourceurl, permission, status, description, createdby, createddate, modifiedby, modifieddate, parentid, parentname, appid, resourceaction, resourceicon, resourcestyle, sortindex, instid) VALUES (E'tesssdf', E'cds', E'111', NULL, NULL, E'1', NULL, NULL, NULL, NULL, NULL, E'1111111', NULL, NULL, NULL, NULL, NULL, 0, E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'1012781571708551168', E'1012780446955601920', E'622227747934179401', E'USER', E'2024-07-22 15:13:28', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'1012782598281232384', E'1012780446955601920', E'622227747934179402', E'USER', E'2024-07-22 15:17:33', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'1012794908634775552', E'1012783210737696768', E'1', E'USER', E'2024-07-22 16:06:28', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'10127966455715594241', E'1012796645571559424', E'1', E'USER-DYNAMIC', E'2026-07-09 12:25:01', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'1012796645571559424622227747934179401', E'1012796645571559424', E'622227747934179401', E'USER-DYNAMIC', E'2026-07-09 12:25:01', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'1012796645571559424622227747934179417', E'1012796645571559424', E'622227747934179417', E'USER-DYNAMIC', E'2026-07-09 12:25:01', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'1012796645571559424622227747934179420', E'1012796645571559424', E'622227747934179420', E'USER-DYNAMIC', E'2026-07-09 12:25:01', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'1012796645571559424622227747934179424', E'1012796645571559424', E'622227747934179424', E'USER-DYNAMIC', E'2026-07-09 12:25:01', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'1012796645571559424622227747934179425', E'1012796645571559424', E'622227747934179425', E'USER-DYNAMIC', E'2026-07-09 12:25:01', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'1012796645571559424622227747934179426', E'1012796645571559424', E'622227747934179426', E'USER-DYNAMIC', E'2026-07-09 12:25:01', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'1012796645571559424622227747934179429', E'1012796645571559424', E'622227747934179429', E'USER-DYNAMIC', E'2026-07-09 12:25:01', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'1012796645571559424622227747934179435', E'1012796645571559424', E'622227747934179435', E'USER-DYNAMIC', E'2026-07-09 12:25:01', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'1012796645571559424684052745233104896', E'1012796645571559424', E'684052745233104896', E'USER-DYNAMIC', E'2026-07-09 12:25:01', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'1012796645571559424799063310631698432', E'1012796645571559424', E'799063310631698432', E'USER-DYNAMIC', E'2026-07-09 12:25:01', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'1012796645571559424799063542492823552', E'1012796645571559424', E'799063542492823552', E'USER-DYNAMIC', E'2026-07-09 12:25:01', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'1012796645571559424799063946328801280', E'1012796645571559424', E'799063946328801280', E'USER-DYNAMIC', E'2026-07-09 12:25:01', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'1012797196401115136', E'1012796645571559424', E'622227747934179401', E'USER', E'2024-07-22 16:15:34', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622178269462003712_1', E'622178269462003712', E'1', E'USER-DYNAMIC', E'2022-06-04 18:21:25', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622178269462003712_622227747934179401', E'622178269462003712', E'622227747934179401', E'USER-DYNAMIC', E'2022-06-04 18:21:25', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622178269462003712_622227747934179402', E'622178269462003712', E'622227747934179402', E'USER-DYNAMIC', E'2022-06-08 22:02:55', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622178269462003712_622227747934179405', E'622178269462003712', E'622227747934179405', E'USER-DYNAMIC', E'2022-06-08 22:02:55', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622178269462003712_622227747934179406', E'622178269462003712', E'622227747934179406', E'USER-DYNAMIC', E'2022-06-08 22:02:55', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622178269462003712_622227747934179407', E'622178269462003712', E'622227747934179407', E'USER-DYNAMIC', E'2022-06-08 22:02:55', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622178269462003712_622227747934179408', E'622178269462003712', E'622227747934179408', E'USER-DYNAMIC', E'2022-06-08 22:02:55', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622178269462003712_622227747934179412', E'622178269462003712', E'622227747934179412', E'USER-DYNAMIC', E'2022-06-08 22:02:55', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622178269462003712_622227747934179413', E'622178269462003712', E'622227747934179413', E'USER-DYNAMIC', E'2022-06-08 22:02:55', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622178269462003712_622227747934179415', E'622178269462003712', E'622227747934179415', E'USER-DYNAMIC', E'2022-06-08 22:02:55', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622178269462003712_622227747934179417', E'622178269462003712', E'622227747934179417', E'USER-DYNAMIC', E'2022-06-08 22:02:55', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622178269462003712_622227747934179418', E'622178269462003712', E'622227747934179418', E'USER-DYNAMIC', E'2022-06-08 22:02:55', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622178269462003712_622227747934179422', E'622178269462003712', E'622227747934179422', E'USER-DYNAMIC', E'2022-06-08 22:02:55', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622178269462003712_622227747934179424', E'622178269462003712', E'622227747934179424', E'USER-DYNAMIC', E'2022-06-04 18:21:25', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622178269462003712_622227747934179426', E'622178269462003712', E'622227747934179426', E'USER-DYNAMIC', E'2022-06-04 18:21:25', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622178269462003712_622227747934179427', E'622178269462003712', E'622227747934179427', E'USER-DYNAMIC', E'2022-06-08 22:02:55', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622178269462003712_622227747934179429', E'622178269462003712', E'622227747934179429', E'USER-DYNAMIC', E'2022-06-08 22:02:55', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622178269462003712_622227747934179431', E'622178269462003712', E'622227747934179431', E'USER-DYNAMIC', E'2022-06-08 22:02:55', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622178269462003712_622227747934179434', E'622178269462003712', E'622227747934179434', E'USER-DYNAMIC', E'2022-06-08 22:02:55', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622178269462003712_622227747938373632', E'622178269462003712', E'622227747938373632', E'USER-DYNAMIC', E'2022-06-08 22:02:55', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622178269462003712_622227747938373633', E'622178269462003712', E'622227747938373633', E'USER-DYNAMIC', E'2022-06-08 22:02:55', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622178269462003712_684052745233104896', E'622178269462003712', E'684052745233104896', E'USER-DYNAMIC', E'2022-06-08 22:02:55', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622178269462003712_699690354462425088', E'622178269462003712', E'699690354462425088', E'USER-DYNAMIC', E'2022-06-08 22:02:55', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622181157164810240622227747934179418', E'622181157164810240', E'622227747934179418', E'USER-DYNAMIC', E'2021-08-09 22:09:33', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622181157164810240622227747934179422', E'622181157164810240', E'622227747934179422', E'USER-DYNAMIC', E'2021-08-09 22:09:33', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622181157164810240622227747934179427', E'622181157164810240', E'622227747934179427', E'USER-DYNAMIC', E'2021-08-09 22:09:33', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622181157164810240_622227747934179420', E'622181157164810240', E'622227747934179420', E'USER-DYNAMIC', E'2022-06-04 13:03:50', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622181157164810240_622227747934179425', E'622181157164810240', E'622227747934179425', E'USER-DYNAMIC', E'2022-12-10 19:00:00', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622181157164810240_622227747934179426', E'622181157164810240', E'622227747934179426', E'USER-DYNAMIC', E'2022-06-06 15:37:28', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622181157164810240_622227747934179429', E'622181157164810240', E'622227747934179429', E'USER-DYNAMIC', E'2022-06-06 15:37:28', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622181157164810240_622227747934179431', E'622181157164810240', E'622227747934179431', E'USER-DYNAMIC', E'2022-06-04 12:50:12', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622181157164810240_622227747934179434', E'622181157164810240', E'622227747934179434', E'USER-DYNAMIC', E'2022-06-04 12:50:12', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622181157164810240_622227747934179435', E'622181157164810240', E'622227747934179435', E'USER-DYNAMIC', E'2022-06-04 13:03:50', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622181157164810240_622227747938373633', E'622181157164810240', E'622227747938373633', E'USER-DYNAMIC', E'2022-06-04 12:50:12', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622181157164810240_622227747938373634', E'622181157164810240', E'622227747938373634', E'USER-DYNAMIC', E'2022-06-04 12:54:20', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622181157164810240_684052745233104896', E'622181157164810240', E'684052745233104896', E'USER-DYNAMIC', E'2022-06-04 12:50:12', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622181157164810240_799023033946734592', E'622181157164810240', E'799023033946734592', E'USER-DYNAMIC', E'2022-12-10 19:00:00', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622181157164810240_799023150116372480', E'622181157164810240', E'799023150116372480', E'USER-DYNAMIC', E'2022-12-10 19:00:00', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622181157164810240_799023247193538560', E'622181157164810240', E'799023247193538560', E'USER-DYNAMIC', E'2022-12-10 19:00:00', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622181157164810240_799023356702621696', E'622181157164810240', E'799023356702621696', E'USER-DYNAMIC', E'2022-12-10 19:00:00', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622181157164810240_799023448587239424', E'622181157164810240', E'799023448587239424', E'USER-DYNAMIC', E'2022-12-10 19:00:00', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622181157164810240_799023558704496640', E'622181157164810240', E'799023558704496640', E'USER-DYNAMIC', E'2022-12-10 19:00:00', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622181157164810240_799023927090216960', E'622181157164810240', E'799023927090216960', E'USER-DYNAMIC', E'2022-12-10 19:00:00', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622181157164810240_799024008602320896', E'622181157164810240', E'799024008602320896', E'USER-DYNAMIC', E'2022-12-10 19:00:00', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622181157164810240_799024095298584576', E'622181157164810240', E'799024095298584576', E'USER-DYNAMIC', E'2022-12-10 19:00:00', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622181157164810240_799024230086737920', E'622181157164810240', E'799024230086737920', E'USER-DYNAMIC', E'2022-12-10 19:00:00', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622181157164810240_799024329139421184', E'622181157164810240', E'799024329139421184', E'USER-DYNAMIC', E'2022-12-10 19:00:00', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622181157164810240_799024459200593920', E'622181157164810240', E'799024459200593920', E'USER-DYNAMIC', E'2022-12-10 19:00:00', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622181157164810240_799024532496056320', E'622181157164810240', E'799024532496056320', E'USER-DYNAMIC', E'2022-12-10 19:00:00', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622181157164810240_799063310631698432', E'622181157164810240', E'799063310631698432', E'USER-DYNAMIC', E'2022-12-10 22:00:00', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622181157164810240_799063542492823552', E'622181157164810240', E'799063542492823552', E'USER-DYNAMIC', E'2022-12-10 22:00:00', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622181157164810240_799063946328801280', E'622181157164810240', E'799063946328801280', E'USER-DYNAMIC', E'2022-12-10 22:00:00', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622183103279923200', E'ROLE_ALL_USER', E'1', E'USER', E'2020-12-12 11:03:10', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622183103330254848', E'ROLE_ADMINISTRATORS', E'1', E'USER', E'2020-12-12 11:03:10', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'622232299202674688', E'ROLE_ADMINISTRATORS', E'2', E'USER', E'2021-08-09 22:10:06', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'667453709277462528', E'622179422249680896', E'1', E'USER', E'2021-12-12 17:03:50', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'680500173679362048', E'622179552155664384', E'622227747934179408', E'USER', E'2022-01-17 17:05:50', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'680500173763248128', E'622179552155664384', E'622227747934179407', E'USER', E'2022-01-17 17:05:50', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'680500173813579776', E'622179552155664384', E'622227747934179406', E'USER', E'2022-01-17 17:05:50', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'680500173872300032', E'622179552155664384', E'622227747934179405', E'USER', E'2022-01-17 17:05:50', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'680500173922631680', E'622179552155664384', E'622227747934179404', E'USER', E'2022-01-17 17:05:50', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'680500173972963328', E'622179552155664384', E'622227747934179403', E'USER', E'2022-01-17 17:05:50', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'680500174006517760', E'622179552155664384', E'622227747934179402', E'USER', E'2022-01-17 17:05:50', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'680500174040072192', E'622179552155664384', E'622227747934179401', E'USER', E'2022-01-17 17:05:50', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'680500174090403840', E'622179552155664384', E'593887578604699648', E'USER', E'2022-01-17 17:05:50', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'680500174144929792', E'622179552155664384', E'1', E'USER', E'2022-01-17 17:05:50', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'707763176233500672', E'622178881788444672', E'1', E'USER', E'2022-04-02 22:39:16', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'707763176338358272', E'622178881788444672', E'622227747934179401', E'USER', E'2022-04-02 22:39:16', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'707763176371912704', E'622178881788444672', E'622227747934179402', E'USER', E'2022-04-02 22:39:16', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'707763176476770304', E'622178881788444672', E'622227747934179403', E'USER', E'2022-04-02 22:39:16', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'707764019208912896', E'622178881788444672', E'622227747934179404', E'USER', E'2022-04-02 22:42:37', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'707764019284410368', E'622178881788444672', E'622227747934179405', E'USER', E'2022-04-02 22:42:37', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'707764019351519232', E'622178881788444672', E'622227747934179406', E'USER', E'2022-04-02 22:42:37', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'707764019418628096', E'622178881788444672', E'622227747934179407', E'USER', E'2022-04-02 22:42:37', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'707764019443793920', E'622178881788444672', E'622227747934179408', E'USER', E'2022-04-02 22:42:37', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'707764029623369728', E'622178881788444672', E'622227747934179409', E'USER', E'2022-04-02 22:42:39', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'707765416973303808', E'622179035744567296', E'622227747934179410', E'USER', E'2022-04-02 22:48:10', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'707765417057189888', E'622179035744567296', E'622227747934179411', E'USER', E'2022-04-02 22:48:10', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'707765417111715840', E'622179035744567296', E'622227747934179412', E'USER', E'2022-04-02 22:48:10', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'707765417166241792', E'622179035744567296', E'622227747934179413', E'USER', E'2022-04-02 22:48:10', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'707765417220767744', E'622179035744567296', E'622227747934179414', E'USER', E'2022-04-02 22:48:10', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'709743952995024896', E'622179035744567296', E'1', E'USER', E'2022-04-08 09:50:10', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'731214824272297984', E'622178518125510656', E'1', E'USER', E'2022-06-06 15:47:45', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'731214824318435328', E'622178518125510656', E'622227747934179401', E'USER', E'2022-06-06 15:47:45', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'731214824368766976', E'622178518125510656', E'622227747934179402', E'USER', E'2022-06-06 15:47:45', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'754998989400571904', E'622178269462003712', E'', E'USER', E'2022-08-11 06:57:31', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'754998989509623808', E'622178269462003712', E'622227747934179404', E'USER', E'2022-08-11 06:57:31', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'837332914076123136', E'837332844740083712', E'', E'USER', E'2023-03-26 11:43:09', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'837332914134843392', E'837332844740083712', E'837332677362188288', E'USER', E'2023-03-26 11:43:09', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_1', E'ROLE_ALL_USER', E'1', E'USER-DYNAMIC', E'2022-04-27 15:01:19', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_622227747934179401', E'ROLE_ALL_USER', E'622227747934179401', E'USER-DYNAMIC', E'2022-04-27 15:01:19', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_622227747934179402', E'ROLE_ALL_USER', E'622227747934179402', E'USER-DYNAMIC', E'2022-04-27 15:01:19', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_622227747934179403', E'ROLE_ALL_USER', E'622227747934179403', E'USER-DYNAMIC', E'2022-04-27 15:01:19', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_622227747934179404', E'ROLE_ALL_USER', E'622227747934179404', E'USER-DYNAMIC', E'2022-04-27 15:01:19', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_622227747934179405', E'ROLE_ALL_USER', E'622227747934179405', E'USER-DYNAMIC', E'2022-04-27 15:01:19', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_622227747934179406', E'ROLE_ALL_USER', E'622227747934179406', E'USER-DYNAMIC', E'2022-04-27 15:01:19', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_622227747934179407', E'ROLE_ALL_USER', E'622227747934179407', E'USER-DYNAMIC', E'2022-04-27 15:01:19', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_622227747934179408', E'ROLE_ALL_USER', E'622227747934179408', E'USER-DYNAMIC', E'2022-04-27 15:01:19', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_622227747934179409', E'ROLE_ALL_USER', E'622227747934179409', E'USER-DYNAMIC', E'2022-04-27 15:01:19', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_622227747934179410', E'ROLE_ALL_USER', E'622227747934179410', E'USER-DYNAMIC', E'2022-04-27 15:01:19', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_622227747934179411', E'ROLE_ALL_USER', E'622227747934179411', E'USER-DYNAMIC', E'2022-04-27 15:01:19', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_622227747934179412', E'ROLE_ALL_USER', E'622227747934179412', E'USER-DYNAMIC', E'2022-04-27 15:01:19', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_622227747934179413', E'ROLE_ALL_USER', E'622227747934179413', E'USER-DYNAMIC', E'2022-04-27 15:01:19', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_622227747934179414', E'ROLE_ALL_USER', E'622227747934179414', E'USER-DYNAMIC', E'2022-04-27 15:01:19', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_622227747934179415', E'ROLE_ALL_USER', E'622227747934179415', E'USER-DYNAMIC', E'2022-04-27 15:01:19', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_622227747934179416', E'ROLE_ALL_USER', E'622227747934179416', E'USER-DYNAMIC', E'2022-04-27 15:01:19', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_622227747934179417', E'ROLE_ALL_USER', E'622227747934179417', E'USER-DYNAMIC', E'2022-04-27 15:01:19', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_622227747934179418', E'ROLE_ALL_USER', E'622227747934179418', E'USER-DYNAMIC', E'2022-04-27 15:01:19', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_622227747934179419', E'ROLE_ALL_USER', E'622227747934179419', E'USER-DYNAMIC', E'2022-04-27 15:01:19', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_622227747934179420', E'ROLE_ALL_USER', E'622227747934179420', E'USER-DYNAMIC', E'2022-04-27 15:01:19', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_622227747934179421', E'ROLE_ALL_USER', E'622227747934179421', E'USER-DYNAMIC', E'2022-04-27 15:01:19', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_622227747934179422', E'ROLE_ALL_USER', E'622227747934179422', E'USER-DYNAMIC', E'2022-04-27 15:01:19', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_622227747934179423', E'ROLE_ALL_USER', E'622227747934179423', E'USER-DYNAMIC', E'2022-04-27 15:01:19', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_622227747934179424', E'ROLE_ALL_USER', E'622227747934179424', E'USER-DYNAMIC', E'2022-04-27 15:01:19', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_622227747934179425', E'ROLE_ALL_USER', E'622227747934179425', E'USER-DYNAMIC', E'2022-04-27 15:01:19', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_622227747934179426', E'ROLE_ALL_USER', E'622227747934179426', E'USER-DYNAMIC', E'2022-04-27 15:01:19', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_622227747934179427', E'ROLE_ALL_USER', E'622227747934179427', E'USER-DYNAMIC', E'2022-04-27 15:01:19', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_622227747934179428', E'ROLE_ALL_USER', E'622227747934179428', E'USER-DYNAMIC', E'2022-04-27 15:01:19', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_622227747934179429', E'ROLE_ALL_USER', E'622227747934179429', E'USER-DYNAMIC', E'2022-04-27 15:01:19', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_622227747934179430', E'ROLE_ALL_USER', E'622227747934179430', E'USER-DYNAMIC', E'2022-04-27 15:01:19', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_622227747934179431', E'ROLE_ALL_USER', E'622227747934179431', E'USER-DYNAMIC', E'2022-04-27 15:01:19', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_622227747934179432', E'ROLE_ALL_USER', E'622227747934179432', E'USER-DYNAMIC', E'2022-04-27 15:01:19', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_622227747934179434', E'ROLE_ALL_USER', E'622227747934179434', E'USER-DYNAMIC', E'2022-04-27 15:01:19', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_622227747934179435', E'ROLE_ALL_USER', E'622227747934179435', E'USER-DYNAMIC', E'2022-04-27 15:01:19', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_622227747938373632', E'ROLE_ALL_USER', E'622227747938373632', E'USER-DYNAMIC', E'2022-04-27 15:01:19', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_622227747938373633', E'ROLE_ALL_USER', E'622227747938373633', E'USER-DYNAMIC', E'2022-04-27 15:01:19', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_622227747938373634', E'ROLE_ALL_USER', E'622227747938373634', E'USER-DYNAMIC', E'2022-04-27 15:01:19', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_684052745233104896', E'ROLE_ALL_USER', E'684052745233104896', E'USER-DYNAMIC', E'2022-04-27 15:01:19', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_799023033946734592', E'ROLE_ALL_USER', E'799023033946734592', E'USER-DYNAMIC', E'2022-12-10 19:00:00', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_799023150116372480', E'ROLE_ALL_USER', E'799023150116372480', E'USER-DYNAMIC', E'2022-12-10 19:00:00', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_799023247193538560', E'ROLE_ALL_USER', E'799023247193538560', E'USER-DYNAMIC', E'2022-12-10 19:00:00', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_799023356702621696', E'ROLE_ALL_USER', E'799023356702621696', E'USER-DYNAMIC', E'2022-12-10 19:00:00', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_799023448587239424', E'ROLE_ALL_USER', E'799023448587239424', E'USER-DYNAMIC', E'2022-12-10 19:00:00', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_799023558704496640', E'ROLE_ALL_USER', E'799023558704496640', E'USER-DYNAMIC', E'2022-12-10 19:00:00', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_799023752670085120', E'ROLE_ALL_USER', E'799023752670085120', E'USER-DYNAMIC', E'2022-12-10 19:00:00', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_799023927090216960', E'ROLE_ALL_USER', E'799023927090216960', E'USER-DYNAMIC', E'2022-12-10 19:00:00', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_799024008602320896', E'ROLE_ALL_USER', E'799024008602320896', E'USER-DYNAMIC', E'2022-12-10 19:00:00', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_799024095298584576', E'ROLE_ALL_USER', E'799024095298584576', E'USER-DYNAMIC', E'2022-12-10 19:00:00', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_799024230086737920', E'ROLE_ALL_USER', E'799024230086737920', E'USER-DYNAMIC', E'2022-12-10 19:00:00', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_799024329139421184', E'ROLE_ALL_USER', E'799024329139421184', E'USER-DYNAMIC', E'2022-12-10 19:00:00', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_799024459200593920', E'ROLE_ALL_USER', E'799024459200593920', E'USER-DYNAMIC', E'2022-12-10 19:00:00', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_799024532496056320', E'ROLE_ALL_USER', E'799024532496056320', E'USER-DYNAMIC', E'2022-12-10 19:00:00', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_799026115950673920', E'ROLE_ALL_USER', E'799026115950673920', E'USER-DYNAMIC', E'2022-12-10 19:00:00', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_799063310631698432', E'ROLE_ALL_USER', E'799063310631698432', E'USER-DYNAMIC', E'2022-12-10 22:00:00', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_799063542492823552', E'ROLE_ALL_USER', E'799063542492823552', E'USER-DYNAMIC', E'2022-12-10 22:00:00', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_799063946328801280', E'ROLE_ALL_USER', E'799063946328801280', E'USER-DYNAMIC', E'2022-12-10 22:00:00', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_799065123216949248', E'ROLE_ALL_USER', E'799065123216949248', E'USER-DYNAMIC', E'2022-12-10 22:00:00', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_799065342516133888', E'ROLE_ALL_USER', E'799065342516133888', E'USER-DYNAMIC', E'2022-12-10 22:00:00', E'1');
INSERT INTO mxk_role_member (id, roleid, memberid, type, createddate, instid) VALUES (E'ROLE_ALL_USER_837332677362188288', E'ROLE_ALL_USER', E'837332677362188288', E'USER-DYNAMIC', E'2023-03-26 12:00:00', E'1');
INSERT INTO mxk_roles (id, rolecode, rolename, category, filters, orgidslist, resumetime, suspendtime, status, isdefault, createdby, createddate, modifiedby, modifieddate, description, instid, appid) VALUES (E'1012780446955601920', E'1111', E'111', E'static', NULL, NULL, E'00:00', E'00:00', 1, 0, E'1', NULL, NULL, NULL, NULL, E'1', E'837136275440926720');
INSERT INTO mxk_roles (id, rolecode, rolename, category, filters, orgidslist, resumetime, suspendtime, status, isdefault, createdby, createddate, modifiedby, modifieddate, description, instid, appid) VALUES (E'1012783210737696768', E'1012783210737696768', E'测试角色', E'static', NULL, NULL, E'00:00', E'00:00', 1, 0, E'1', NULL, NULL, NULL, NULL, E'1', E'622227747938373638');
INSERT INTO mxk_roles (id, rolecode, rolename, category, filters, orgidslist, resumetime, suspendtime, status, isdefault, createdby, createddate, modifiedby, modifieddate, description, instid, appid) VALUES (E'1012796645571559424', E'1012796645571559424', E'测试角色2', E'dynamic', NULL, E'1,103,104,105,106,107,', E'00:00', E'00:00', 1, 0, E'1', NULL, E'1', E'2026-07-09 12:25:02', NULL, E'1', E'622227747938373638');
INSERT INTO mxk_socials_provider (id, provider, providername, icon, clientid, clientsecret, agentid, display, sortindex, scancode, status, createdby, createddate, modifiedby, modifieddate, instid) VALUES (E'1', E'wechatopen', E'微信', E'assets/social/wechat.png', E'ee6fdc484b3398d17e7', E'$2a$10$3n3bK6dgJoyOamplqgysO.cef925a7cec274c3f835ce0a3b2c0c603ed6febb07120b900852d62bc605fb0bc38942f3bab4ebc1', E'none', E'false', 1, E'false', 1, NULL, NULL, NULL, NULL, E'1');
INSERT INTO mxk_socials_provider (id, provider, providername, icon, clientid, clientsecret, agentid, display, sortindex, scancode, status, createdby, createddate, modifiedby, modifieddate, instid) VALUES (E'10', E'feishu', E'飞书', E'assets/social/feishu.png', E'cli_a1615958b0381013', E'$2a$10$M.RbHzCf43kh0i4gM1vdV.4e66a3ac90e16cd980516cd7ba92e8ff8ab2e935343fb03ab45d9decd8769f480dfb98ba548665b0860ee37c2dddb875221dca3155329b08', E'none', E'false', 10, E'false', 1, NULL, NULL, E'1', E'2025-11-01 18:40:25', E'1');
INSERT INTO mxk_socials_provider (id, provider, providername, icon, clientid, clientsecret, agentid, display, sortindex, scancode, status, createdby, createddate, modifiedby, modifieddate, instid) VALUES (E'11', E'twitter', E'Twitter', E'assets/social/twitter.png', E'24aa73b6-7928-4e64-bd64-d8682e650f95', E'$2a$10$J9uFgCSONhGNmrYV12ncg.c84535785c5333b07b345128fea4f5e79e38b25e4f86cac396801a891730995c', E'none', E'false', 11, E'false', 1, NULL, NULL, NULL, NULL, E'1');
INSERT INTO mxk_socials_provider (id, provider, providername, icon, clientid, clientsecret, agentid, display, sortindex, scancode, status, createdby, createddate, modifiedby, modifieddate, instid) VALUES (E'12', E'linkedin', E'LinkediIn', E'assets/social/linkedin.png', E'cli_a1615958b0381013', E'$2a$10$zIgwS.3.wqmxyr4Ybfcnje2130f4ac787a534081a1f1a8277a8bcfeb69c3e1e2d4549b889f123624271c80727d36d1a549b7e288567f0a6494d8e26142123732514594', E'none', E'false', 12, E'false', 1, NULL, NULL, NULL, NULL, E'1');
INSERT INTO mxk_socials_provider (id, provider, providername, icon, clientid, clientsecret, agentid, display, sortindex, scancode, status, createdby, createddate, modifiedby, modifieddate, instid) VALUES (E'13', E'alipay', E'支付宝', E'assets/social/alipay.png', E'cli_a1615958b0381013', E'$2a$10$nM0MgVT11Z9W0qqd/.yhq.bc141f6167d69ade23e761c0ae0397191931694b4be506ba91a14a6908c596aa4f45a6caed202c8af02c484ad0771ce017977ebc3ded3ebf', E'none', E'false', 13, E'false', 1, NULL, NULL, NULL, NULL, E'1');
INSERT INTO mxk_socials_provider (id, provider, providername, icon, clientid, clientsecret, agentid, display, sortindex, scancode, status, createdby, createddate, modifiedby, modifieddate, instid) VALUES (E'14', E'baidu', E'百度', E'assets/social/baidu.png', E'appKey', E'$2a$10$VdXXbwezBPLFowYy/ZbZr.add2b250cdbd19055fe0194a4f9e048f7570c35da026e6f4dcea4c2a754d6651', E'none', E'false', 14, E'false', 1, NULL, NULL, NULL, NULL, E'1');
INSERT INTO mxk_socials_provider (id, provider, providername, icon, clientid, clientsecret, agentid, display, sortindex, scancode, status, createdby, createddate, modifiedby, modifieddate, instid) VALUES (E'15', E'jd', E'京东', E'assets/social/jd.png', E'appKey', E'$2a$10$XDKkuL2.4rrRRIcD9JR8ge21c9a92daf7a5c1ef571a75f648e3b524db13b74dd9a7bea464c4792386bcc79', E'none', E'false', 15, E'false', 1, NULL, NULL, NULL, NULL, E'1');
INSERT INTO mxk_socials_provider (id, provider, providername, icon, clientid, clientsecret, agentid, display, sortindex, scancode, status, createdby, createddate, modifiedby, modifieddate, instid) VALUES (E'16', E'amazon', E'Amazon', E'assets/social/amazon.png', E'appKey', E'$2a$10$ZylPpIqCr3KRpnChkYOPFO49ce02b1ede0aba55735e769f6c648f392ea0d82ee752b967ccdd598f2e066fe', E'none', E'false', 16, E'false', 1, NULL, NULL, NULL, NULL, E'1');
INSERT INTO mxk_socials_provider (id, provider, providername, icon, clientid, clientsecret, agentid, display, sortindex, scancode, status, createdby, createddate, modifiedby, modifieddate, instid) VALUES (E'17', E'douyin', E'抖音', E'assets/social/douyin.png', E'appKey', E'$2a$10$6/qwzdTAGfSVv1.lhzMHhO42b7611512ea042b4f1eba340106e1e978977cc72a7e0268665186a4ffd8f7c0', E'none', E'false', 17, E'false', 1, NULL, NULL, NULL, NULL, E'1');
INSERT INTO mxk_socials_provider (id, provider, providername, icon, clientid, clientsecret, agentid, display, sortindex, scancode, status, createdby, createddate, modifiedby, modifieddate, instid) VALUES (E'18', E'github', E'GitHub', E'assets/social/github.png', E'appKey', E'$2a$10$ph4IHd9K6epEGUbHlnrqn.708a1dff89a5475e2d529a6a5494be03c27d621c2ba5b7a314d696af6ae28e26', E'none', E'false', 18, E'false', 1, NULL, NULL, NULL, NULL, E'1');
INSERT INTO mxk_socials_provider (id, provider, providername, icon, clientid, clientsecret, agentid, display, sortindex, scancode, status, createdby, createddate, modifiedby, modifieddate, instid) VALUES (E'19', E'gitlab', E'gitlab', E'assets/social/gitlab.png', E'appKey', E'$2a$10$mSXdYIr34m4EgBm9qbKsD.7c4365a05bd2ba22ea275c03fdb56fb11796c39be0df7212e560ca13bc7b095b', E'none', E'false', 19, E'false', 1, NULL, NULL, NULL, NULL, E'1');
INSERT INTO mxk_socials_provider (id, provider, providername, icon, clientid, clientsecret, agentid, display, sortindex, scancode, status, createdby, createddate, modifiedby, modifieddate, instid) VALUES (E'2', E'workweixin', E'企业微信', E'assets/social/wechat_enterprise.png', E'ww61ca142e1fe5b8ca', E'$2a$10$esMk.6VtjvgcaDvjF/NFXe0a767cf574a2e02198a8538830835c6321bd01de7afd982ffeacb09c94afef360d90e981604ac7b7475581896fa32071c34cf6b869985dbedba98274b910df0fa092b41b9ac24f8c', E'1000002', E'true', 2, E'false', 1, NULL, NULL, NULL, NULL, E'1');
INSERT INTO mxk_socials_provider (id, provider, providername, icon, clientid, clientsecret, agentid, display, sortindex, scancode, status, createdby, createddate, modifiedby, modifieddate, instid) VALUES (E'20', E'meituan', E'美团', E'assets/social/meituan.png', E'appKey', E'$2a$10$1JF4suE51sQziw6gyhtGmO9346c03a8bec2d66c5347a3da80284c47b71e90fb5d29a2731bb0beb6a83ecee', E'none', E'false', 20, E'false', 1, NULL, NULL, NULL, NULL, E'1');
INSERT INTO mxk_socials_provider (id, provider, providername, icon, clientid, clientsecret, agentid, display, sortindex, scancode, status, createdby, createddate, modifiedby, modifieddate, instid) VALUES (E'21', E'welink', E'华为WeLink', E'assets/social/welink.png', E'20220123170404387621138', E'$2a$10$uUZhIZz7ru9oGHJUwMVptu95510c9e83f23b941bfefce9c8007e939bce080c367e812e03353070e1aa4c9419571d37f15b2d759a01108d3ac11f9a8fa652481b0430ea85b533acd0cea4d6', E'none', E'false', 21, E'false', 1, NULL, NULL, NULL, NULL, E'1');
INSERT INTO mxk_socials_provider (id, provider, providername, icon, clientid, clientsecret, agentid, display, sortindex, scancode, status, createdby, createddate, modifiedby, modifieddate, instid) VALUES (E'3', E'sinaweibo', E'微博', E'assets/social/weibo.png', E'3379757634', E'$2a$10$N6TZ31Tl5MVzS9tTxpUZv.78a6853370088a24e85cdcad998b81e7793909ccf17ab27296c6e79c8dc01fcf6f2927fb890e69335ec6e0552fb5d222c2d5da0af957b039', E'none', E'false', 3, E'false', 1, NULL, NULL, NULL, NULL, E'1');
INSERT INTO mxk_socials_provider (id, provider, providername, icon, clientid, clientsecret, agentid, display, sortindex, scancode, status, createdby, createddate, modifiedby, modifieddate, instid) VALUES (E'4', E'dingtalk', E'钉钉', E'assets/social/dingtalk.png', E'dingoawf2jyiwh2uzqnphg', E'$2a$10$2KdUt6nAxurF08fpRmx4Zef6d77c0e9b31c3c5fe8b84d067a26ba877f357743adc5c9b81d9c270e803161c29d232437ebd5692e71cd7c4cfa6213fa4a5c74ac8ee79651e72ea688ba1aa9d978f1e21618963343f51c5cdafd7dc9a73f5d177162b06dd', E'none', E'true', 4, E'true', 1, NULL, NULL, E'1', E'2025-11-01 18:40:33', E'1');
INSERT INTO mxk_socials_provider (id, provider, providername, icon, clientid, clientsecret, agentid, display, sortindex, scancode, status, createdby, createddate, modifiedby, modifieddate, instid) VALUES (E'5', E'gitee', E'Gitee', E'assets/social/gitee.png', E'ee6fdc484b3398d17e77d6ff37fd8b9fe502106398c7b22bf5522d3c01303f45', E'$2a$10$VJUoSi1jaiJhKN6iD5rQ4e8f017f536ad17d5327750308c71f7fdf474a622ce1baa77ddc6d512a96b2871c23e26d444278c7495c1ff3cab018718216639e93e5445c88a21aa64d4e82ae9cc78451bd984fecdfc4783ea689e491483fe7d2127fbd21e1', E'none', E'false', 5, E'false', 1, NULL, NULL, NULL, NULL, E'1');
INSERT INTO mxk_socials_provider (id, provider, providername, icon, clientid, clientsecret, agentid, display, sortindex, scancode, status, createdby, createddate, modifiedby, modifieddate, instid) VALUES (E'6', E'google', E'Google', E'assets/social/google.png', E'519914515488.apps.googleusercontent.com', E'$2a$10$jyNkczOcFuPXX2ksFEauV.3c52e0c6809a0f030e01863a83bcc86621030babe33592336b5be715bd8721dcbd245c250d68a0d034a133240b85c4c0', E'none', E'false', 6, E'false', 1, NULL, NULL, NULL, NULL, E'1');
INSERT INTO mxk_socials_provider (id, provider, providername, icon, clientid, clientsecret, agentid, display, sortindex, scancode, status, createdby, createddate, modifiedby, modifieddate, instid) VALUES (E'7', E'qq', E'QQ', E'assets/social/qq.png', E'101225363', E'$2a$10$FhIfpzKiLY58TigkysX.z.4ddfd4285ac40fec382c3e747efd718a47c63b9542a54212241477b0351403b756e6c90d0dbe915715f88e6bb09f4c4dec65a4823972fc1e', E'none', E'false', 7, E'false', 1, NULL, NULL, NULL, NULL, E'1');
INSERT INTO mxk_socials_provider (id, provider, providername, icon, clientid, clientsecret, agentid, display, sortindex, scancode, status, createdby, createddate, modifiedby, modifieddate, instid) VALUES (E'8', E'microsoft', E'Microsoft', E'assets/social/microsoft.png', E'24aa73b6-7928-4e64-bd64-d8682e650f95', E'$2a$10$yApQJkLORzTwZRpDOBs2N.35d5fa60317df31d5b55f605ca6efe06eb22de89921f219d360aa579bcf4e23dc629e2fd2467edd3c70d4cf245597a8eeeef18d16be00e9e', E'none', E'true', 8, E'false', 1, NULL, NULL, NULL, NULL, E'1');
INSERT INTO mxk_socials_provider (id, provider, providername, icon, clientid, clientsecret, agentid, display, sortindex, scancode, status, createdby, createddate, modifiedby, modifieddate, instid) VALUES (E'9', E'facebook', E'Facebook', E'assets/social/facebook.png', E'appKey', E'$2a$10$dNwwCB4sdVtCKLmKzy0boubff8df2d163806a9dc7a9b548115dc4acc8e890374cebf3f06cbc94776dbf407', E'none', E'true', 9, E'false', 1, NULL, NULL, NULL, NULL, E'1');
ALTER TABLE mxk_synchro_association ALTER COLUMN id RESTART WITH 210;
INSERT INTO mxk_userinfo (id, username, password, decipherable, authntype, mobile, mobileverified, email, emailverified, displayname, nickname, picture, timezone, locale, preferredlanguage, passwordquestion, passwordanswer, apploginauthntype, apploginpassword, protectedapps, theme, gridlist, logincount, "online", status, islocked, unlocktime, lastloginip, lastlogintime, lastlogofftime, badpasswordtime, badpasswordcount, passwordlastsettime, passwordsettype, sharedsecret, sharedcounter, usertype, userstate, employeenumber, windowsaccount, division, costcenter, organization, departmentid, department, jobtitle, joblevel, managerid, manager, assistantid, assistant, entrydate, startworkdate, quitdate, sortindex, workemail, workphonenumber, workcountry, workregion, worklocality, workstreetaddress, workaddressformatted, workpostalcode, workfax, workofficename, givenname, middlename, familyname, honorificprefix, honorificsuffix, formattedname, idtype, idcardno, education, graduatefrom, graduatedate, married, birthdate, namezhspell, namezhshortspell, gender, website, weixinfollow, defineim, homeemail, homephonenumber, homecountry, homeregion, homelocality, homestreetaddress, homeaddressformatted, homepostalcode, homefax, extraattribute, createdby, createddate, modifiedby, modifieddate, description, ldapdn, instid, regionhistory, passwordhistory) VALUES (E'1', E'admin', E'{plain}maxkey', E'', 0, E'15618726256', E'0', E'shimingxy@qq.com', 0, E'系统管理员', E'系统管理员', NULL, E'Asia/Shanghai', E'de', E'zh_CN', E'5', E'wusdfdsf', 0, E'96ba45115416faf22791c13ade20f437', E',41065fe3-ae67-4172-a460-fd0079e88294,52f0002d-4ef7-4b27-8c5b-41b9ee80835d,3f57d0b2-99ab-4e66-a938-718befb55369', E'default', 0, 1840, 0, 1, 1, E'2022-05-18 03:58:47', E'0:0:0:0:0:0:0:1', E'2026-07-20 20:06:04', E'2026-07-20 20:10:00', E'2023-10-11 11:29:06', 0, E'2022-04-25 20:12:05', 0, E'$2a$10$B.lYrMtrkjHhK4qBPhtf.ec3d523ce1a4e4d1453f56d94f2ea5d4d76a5688d16b5fc9e8b71810a66b5016c6556dc432c7dd48eb4417c67b4c34fad7346bcf52de3acf8', NULL, E'EMPLOYEE', E'RESIDENT', E'2099001', E'adsystemadmin', NULL, NULL, E'总部', E'105', E'科技部', E'系统管理员', NULL, E'22222', E'科技部经理', NULL, NULL, NULL, NULL, NULL, 0, E'admin@QxzyC82JWA-mail.com', E'123123', E'AFG', E'北京', E'北京', E'北京', NULL, E'123123', E'123123', NULL, E'admin', E'admin', E'admin', NULL, NULL, NULL, 1, E'2342342343242344234', E'', E'', NULL, 1, NULL, NULL, NULL, 1, E'http://login.maxkey.org/', NULL, NULL, E'admin@qq.com', E'123123', E'AFG', E'北京', E'北京', E'北京', NULL, E'123123', E'sdf', NULL, NULL, E'2014-01-21 00:00:00', NULL, E'2025-07-27 11:45:09', NULL, NULL, E'1', NULL, NULL);

