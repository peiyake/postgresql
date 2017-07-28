------------------------------------------------------------------------------------------------------------------------
--	1. 	创建一个数据库 ac
--	2.	ac数据库包含4张表 
--	ap_setup  		ap级配置表
--	wifi_setup  	wifi卡级配置表
--	vap_setup		vap级配置表
--	opt_history		记录对ac数据库的所有操作记录
--	3.	表结构
--	ap_setup 包含:
--	apid 			不能为空 / 大于33 小于1000033/不能重复
--	inster_time		数据插入时间  精确到秒 
--	
--	wifi_setup 包含:
--	apid			不能为空 / 大于33 小于10033 /不能重复
--	wifiid			不能为空 / 大于0 小于2/不能重复 
--	inster_time		数据插入时间  精确到秒
--	
--	vap_setup 包含:
--	apid			不能为空 / 大于33 小于10033
--	wifiid			不能为空 / 范围0-1 /不能重复
--	vapid			不能为空 / 范围0-15	 /不能重复
--	inster_time		数据插入时间  精确到秒
--	
--	opt_history 包含:
--	inster_time		数据插入时间  精确到秒
--	username		操作ac数据库的用户名
--	tablename		操作过的表名
--	opttype			进行过何种操作/inster/update/delete
	
--	4.	约束说明
--	1.	删除表ap_setup中一条数据时,必须同时删除wifi_setup和vap_setup表中相同apid的记录
--	2.	删除wifi_setup中一条数据记录时,必须同时删除vap_setup表中相同apid+wifiid的记录
--	3.	向ap_setup表中插入数据时,必须同时向wifi_setup和vap_setup中插入一条记录,(被动插入的这两条记录使用默认值)
--	4.	对ac数据库每张表的操作都记录到optr_history表中
--------------------------------------------------------------------------------------------------------------------------
	
DROP DATABASE IF EXISTS ac;
--创建ac数据库
CREATE DATABASE ac;	
\c ac
--创建表ap_setup				
CREATE TABLE ap_setup(
	apid 			int			NOT NULL,									--非空约束
	inster_time		timestamp	NOT NULL  		DEFAULT now(),				--非空约束 and  默认值当前时间
	CHECK (apid > 32 AND apid < 1000034),			--表级检查约束
	UNIQUE	(apid)									--表级唯一约束
);
--创建表wifi_setup
CREATE TABLE wifi_setup(
	apid 			int			NOT NULL,
	wifiid			int			NOT	NULL		DEFAULT 0,
	inster_time		timestamp	NOT NULL  		DEFAULT now(),
	CHECK (apid > 32 AND apid < 1000034),
	CHECK (wifiid >= 0 AND wifiid <= 1),
	UNIQUE (apid,wifiid)	
);
--创建表vap_setup
CREATE TABLE vap_setup(
	apid 			int			NOT NULL,
	wifiid			int			NOT	NULL		DEFAULT 0,
	vapid			int			NOT	NULL		DEFAULT	0,
	inster_time		timestamp	NOT NULL  		DEFAULT now(),
	CHECK  (apid > 32 AND apid < 1000034),
	CHECK  (wifiid >= 0 AND wifiid <= 1),
	CHECK  (vapid >= 0 AND vapid <= 15),
	UNIQUE (apid,wifiid,vapid)	
);
--创建表opt_history
CREATE TABLE opt_history(
	insert_time		timestamp	NOT NULL,
	username		varchar(32)	NOT	NULL,
	tablename		varchar(32),
	opttype			varchar(16)
);
--主键列表
ALTER TABLE ap_setup 	ADD CONSTRAINT ap_setup_pkey 		PRIMARY KEY (apid);					--表ap_setup中 	apid为主键
ALTER TABLE wifi_setup 	ADD CONSTRAINT wifi_setup_pkey 		PRIMARY KEY (apid,wifiid);			--表wifi_setup中 apid+wifiid为主键
ALTER TABLE vap_setup 	ADD CONSTRAINT vap_setup_pkey 		PRIMARY KEY (apid,wifiid,vapid);	--表vap_setup中 apid+wifiid+vapid为主键
--外键列表	(这个外键设置的有问题, 会造成向ap_setup插入数据时无法插入成功, 与约束3矛盾)
--ALTER TABLE wifi_setup 	ADD CONSTRAINT wifi_setup_fkey 		FOREIGN KEY (apid)				REFERENCES ap_setup(apid);		--表wifi_setup中的apid必须在ap_setup中存在
--ALTER TABLE vap_setup 	ADD CONSTRAINT vap_setup_fkey1 		FOREIGN KEY (apid,wifiid)		REFERENCES wifi_setup(apid,wifiid);		--表vap_setup中的apid必须在ap_setup中存在

--触发器函数 删除ap时,同时删除wifi_setup和vap_setup中存在的vapid
CREATE OR REPLACE FUNCTION func_ap_setup_del()			RETURNS TRIGGER AS 
$$
BEGIN
	DELETE FROM wifi_setup 	WHERE apid=OLD.apid;
	DELETE FROM vap_setup 	WHERE apid=OLD.apid;
	RETURN OLD;
END;
$$	LANGUAGE plpgsql;
--触发器函数  删除wifi_setup中一条数据记录时,同步删除vap_setup中相同apid+wifiid的记录
CREATE OR REPLACE FUNCTION func_wifi_setup_del()		RETURNS TRIGGER AS 
$$
BEGIN
	DELETE FROM vap_setup 	WHERE apid=OLD.apid AND wifiid=OLD.wifiid;
	RETURN OLD;
END;
$$	LANGUAGE plpgsql;
--触发器函数, 对所有表操作时,都在历史表中插入一条记录
CREATE OR REPLACE FUNCTION func_inster_opt_history()	RETURNS TRIGGER AS 
$$
BEGIN
	INSERT INTO opt_history VALUES(now(),user,TG_TABLE_NAME,TG_OP);
	RETURN NULL;
END;
$$	LANGUAGE plpgsql;
--触发器函数, 向ap_setup表中插入数据时,同时向wifi_setup和vap_setup中插入一条记录
CREATE OR REPLACE FUNCTION func_inster_ap_setup()	RETURNS TRIGGER AS 
$$
BEGIN
	INSERT INTO wifi_setup 	VALUES 	(NEW.apid ,DEFAULT);
	INSERT INTO vap_setup 	VALUES	(NEW.apid ,DEFAULT);
	RETURN NEW;
END;
$$	LANGUAGE plpgsql;
CREATE TRIGGER tg_del_ap_setup 			AFTER 	DELETE ON ap_setup 							FOR EACH ROW EXECUTE PROCEDURE func_ap_setup_del();
CREATE TRIGGER tg_ins_ap_setup 			BEFORE 	INSERT ON ap_setup 							FOR EACH ROW EXECUTE PROCEDURE func_inster_ap_setup();
CREATE TRIGGER tg_del_wifi_setup 		AFTER 	DELETE ON wifi_setup 						FOR EACH ROW EXECUTE PROCEDURE func_wifi_setup_del();
CREATE TRIGGER tg_dml_ap_setup 			AFTER 	DELETE OR UPDATE OR INSERT ON ap_setup 		FOR EACH ROW EXECUTE PROCEDURE func_inster_opt_history();
CREATE TRIGGER tg_dml_wifi_setup 		AFTER 	DELETE OR UPDATE OR INSERT ON wifi_setup 	FOR EACH ROW EXECUTE PROCEDURE func_inster_opt_history();
CREATE TRIGGER tg_dml_vap_setup 		AFTER 	DELETE OR UPDATE OR INSERT ON vap_setup 	FOR EACH ROW EXECUTE PROCEDURE func_inster_opt_history();
