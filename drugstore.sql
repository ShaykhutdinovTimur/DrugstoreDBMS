--PostgreSQL
DROP DATABASE IF EXISTS DrugstoreBase;
CREATE DATABASE DrugstoreBase;
\c DrugstoreBase

DROP TABLE IF EXISTS Provider CASCADE;
CREATE TABLE Provider(
	pid INT PRIMARY KEY,
	pname VARCHAR(50) NOT NULL,

	UNIQUE(pname)
);

DROP TABLE IF EXISTS Drugstore CASCADE;
CREATE TABLE Drugstore(
	sid INT PRIMARY KEY,
	sname VARCHAR(50) NOT NULL,

	UNIQUE(sname)
);

DROP TABLE IF EXISTS Customer CASCADE;
CREATE TABLE Customer(
	cid INT PRIMARY KEY,
	cname VARCHAR(50) NOT NULL,

	UNIQUE(cname)
);

--это не группы препаратов (жаропонижающие), а группы условий продажи
DROP TABLE IF EXISTS DGroup CASCADE;
CREATE TABLE Dgroup(
	gid INT PRIMARY KEY,
	gname VARCHAR(100) NOT NULL,

	UNIQUE(gname)
);

DROP TABLE IF EXISTS Illness CASCADE;
CREATE TABLE Illness(
	iid INT PRIMARY KEY,
	iname VARCHAR(100) NOT NULL,

	UNIQUE(iname)
);

DROP TABLE IF EXISTS Medicine CASCADE;
CREATE TABLE Medicine(
	mid INT PRIMARY KEY,
	mname VARCHAR(50) NOT NULL,
	gid INT NOT NULL,
	
	FOREIGN KEY (gid) REFERENCES DGroup(gid) ON DELETE CASCADE,
	UNIQUE(mname)
);

DROP TABLE IF EXISTS IndicationsForUse CASCADE;
CREATE TABLE IndicationsForUse(
	mid INT,
	iid INT,

	PRIMARY KEY (mid, iid),
	FOREIGN KEY (mid) REFERENCES Medicine(mid) ON DELETE CASCADE,
	FOREIGN KEY (iid) REFERENCES Illness(iid) ON DELETE CASCADE
);

DROP TABLE IF EXISTS COrder CASCADE;
CREATE TABLE COrder(
	oid INT PRIMARY KEY
	sid INT NOT NULL,
	cid INT NOT NULL,

	FOREIGN KEY (sid) REFERENCES Drugstore(sid) ON DELETE CASCADE,
	FOREIGN KEY (cid) REFERENCES Custumer(cid) ON DELETE CASCADE
);

DROP TABLE IF EXISTS DrugsInOrder CASCADE;
CREATE TABLE DrugsInOrder(
	mid INT,
	oid INT,
	cnt INT NOT NULL,
	price INT NOT NULL, --for 1 item 

	PRIMARY KEY (mid, oid),
	FOREIGN KEY (mid) REFERENCES Medicine(mid) ON DELETE CASCADE,
	FOREIGN KEY (oid) REFERENCES COrder(oid) ON DELETE CASCADE
);

DROP TABLE IF EXISTS DrugsInStore CASCADE;
CREATE TABLE DrugsInStore(
	mid INT,
	sid INT,
	cnt INT NOT NULL,
	price INT NOT NULL, --for 1 item 

	PRIMARY KEY (mid, sid),
	FOREIGN KEY (mid) REFERENCES Medicine(mid) ON DELETE CASCADE,
	FOREIGN KEY (sid) REFERENCES Drugstore(sid) ON DELETE CASCADE
);

DROP TABLE IF EXISTS Delivery CASCADE;
CREATE TABLE Delivery(
	did INT PRIMARY KEY,
	pid INT NOT NULL,
	sid INT NOT NULL,

	FOREIGN KEY (pid) REFERENCES Provider(pid) ON DELETE CASCADE,
	FOREIGN KEY (sid) REFERENCES Drugstore(sid) ON DELETE CASCADE
);

DROP TABLE IF EXISTS DrugsInDelivery CASCADE;
CREATE TABLE DrugsInDelivery(
	mid INT,
	did INT,
	cnt INT NOT NULL,
	price INT NOT NULL, --for 1 item 

	PRIMARY KEY (mid, iid),
	FOREIGN KEY (mid) REFERENCES Medicine(mid) ON DELETE CASCADE,
	FOREIGN KEY (did) REFERENCES Delivery(did) ON DELETE CASCADE
);