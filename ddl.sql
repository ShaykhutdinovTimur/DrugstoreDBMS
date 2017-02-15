--PostgreSQL
DROP DATABASE IF EXISTS DrugstoreBase;
CREATE DATABASE DrugstoreBase;
\c DrugstoreBase

DROP TABLE IF EXISTS Providers CASCADE;
CREATE TABLE Providers(
	Id INT PRIMARY KEY,
	Name VARCHAR(50) NOT NULL,
	Requisites VARCHAR(10) NOT NULL,

	UNIQUE(Requisites)
);

DROP TABLE IF EXISTS Drugstores CASCADE;
CREATE TABLE Drugstores(
	Id INT PRIMARY KEY,
	Address VARCHAR(50) NOT NULL,
	SignboardOutside boolean NOT NULL,
	Requisites VARCHAR(10) NOT NULL,

	UNIQUE(Requisites)
);

DROP TABLE IF EXISTS Customers CASCADE;
CREATE TABLE Customers(
	Id INT PRIMARY KEY,
	Requisites VARCHAR(10) NOT NULL,

	UNIQUE(Requisites)
);

--это группы препаратов (жаропонижающие)
--для простоты каждый препарат  принадлежит одной группе
DROP TABLE IF EXISTS GroupsOfDrugs CASCADE;
CREATE TABLE GroupsOfDrugs(
	Id INT PRIMARY KEY,
	Name VARCHAR(50),
	FullName VARCHAR(50) NOT NULL,
	ReceipNeed boolean NOT NULL
);

DROP TABLE IF EXISTS Illnesses CASCADE;
CREATE TABLE Illnesses(
	Id INT PRIMARY KEY,
	Name VARCHAR(50),
	FullName VARCHAR(50) NOT NULL
);

DROP TABLE IF EXISTS Medicines CASCADE;
CREATE TABLE Medicines(
	Id INT PRIMARY KEY,
	Name VARCHAR(50),
	FullName VARCHAR(50) NOT NULL,
	Gid INT NOT NULL,
	
	FOREIGN KEY (Gid) REFERENCES GroupsOfDrugs(Id) ON DELETE CASCADE
);

DROP TABLE IF EXISTS Indications CASCADE;
CREATE TABLE Indications(
	Mid INT,
	Iid INT,
	Time VARCHAR(50) NOT NULL,
	Method VARCHAR(50) NOT NULL,
	Contraindications VARCHAR(50) NOT NULL,
	Ccount INT NOT NULL,

	PRIMARY KEY (Mid, Iid),
	FOREIGN KEY (Mid) REFERENCES Medicines(Id) ON DELETE CASCADE,
	FOREIGN KEY (Iid) REFERENCES Illnesses(Id) ON DELETE CASCADE
);

DROP TABLE IF EXISTS Orders CASCADE;
CREATE TABLE Orders(
	Did INT,
	Cid INT,
	Time TIMESTAMP, 
	HasReceip boolean NOT NULL,
	
	
	PRIMARY KEY (Did, Cid, Time),
	FOREIGN KEY (Did) REFERENCES Drugstores(Id) ON DELETE CASCADE,
	FOREIGN KEY (Cid) REFERENCES Custumers(Id) ON DELETE CASCADE
);

DROP TABLE IF EXISTS OrdersAmounts CASCADE;
CREATE TABLE DrugsInOrder(
	Mid INT,
	Cid INT,
	Did INT,
	Time TIMESTAMP,
	Ccount INT NOT NULL,

	PRIMARY KEY (Mid, Cid, Did, Time),
	FOREIGN KEY (Mid) REFERENCES Medicines(Id) ON DELETE CASCADE,
	FOREIGN KEY (Cid, Did, Time) REFERENCES Orders(Cid, Did, Time) ON DELETE CASCADE
);

DROP TABLE IF EXISTS DrugstoresAmounts CASCADE;
CREATE TABLE DrugstoresAmounts(
	Mid INT,
	Did INT,
	Ccount INT NOT NULL,
	Price INT NOT NULL, --for 1 item 

	PRIMARY KEY (Mid, Did),
	FOREIGN KEY (Mid) REFERENCES Medicines(Id) ON DELETE CASCADE,
	FOREIGN KEY (Did) REFERENCES Drugstores(Id) ON DELETE CASCADE
);

DROP TABLE IF EXISTS Deliveries CASCADE;
CREATE TABLE Deliveries(	
	Pid INT,
	Did INT,
	Time TIMESTAMP,

	PRIMARY KEY (Pid, Did, Time)
	FOREIGN KEY (Pid) REFERENCES Providers(Id) ON DELETE CASCADE,
	FOREIGN KEY (Did) REFERENCES Drugstores(Id) ON DELETE CASCADE
);

DROP TABLE IF EXISTS DeliveriesAmounts CASCADE;
CREATE TABLE DeliveriesAmounts(
	Mid INT,
	Did INT,
	Pid INT,
	Time TIMESTAMP,
	Ccount INT NOT NULL,
	Price INT NOT NULL, --for 1 item 

	PRIMARY KEY (Mid, Pid, Did, Time),
	FOREIGN KEY (Mid) REFERENCES Medicines(Id) ON DELETE CASCADE,
	FOREIGN KEY (Did, Pid, Time) REFERENCES Deliveries(Did, Pid, Time) ON DELETE CASCADE
);

DROP TABLE IF EXISTS IllnessesOfCustomes CASCADE;
CREATE TABLE IllnessesOfCustomers(
	Iid INT,
	Cid INT,
	Did INT,
	Time TIMESTAMP,
	
	PRIMARY KEY (Iid, Cid, Did, Time),
	FOREIGN KEY (Iid) REFERENCES Illnesses(Id) ON DELETE CASCADE,
	FOREIGN KEY (Cid, Did, Time) REFERENCES Orders(Cid, Did, Time) ON DELETE CASCADE
);
	
DROP TABLE IF EXISTS GroupsInReceips CASCADE;
CREATE TABLE GroupsInReceips(
	Gid INT,
	Cid INT,
	Did INT,
	Time TIMESTAMP,
	
	PRIMARY KEY (Gid, Cid, Did, Time),
	FOREIGN KEY (Gid) REFERENCES GroupsOfDrugs(Id) ON DELETE CASCADE,
	FOREIGN KEY (Cid, Did, Time) REFERENCES Orders(Cid, Did, Time) ON DELETE CASCADE
);

--ТРИГГЕРЫ
--Покупатель имеет право приобретать разрешенные группы медикаментов
--при этом может купить не болше доступного количества
CREATE OF REPLACE FUNCTION checkReceip() RETURNS TRIGGER language plpsql AS $$
DECLARE
	ordered record;
	drugcnt record;
BEGIN
	IF (new.Cid IS NOT NULL AND new.Did IS NOT NULL AND new.Mid IS NOT NULL AND new.Ccount IS NOT NULL) THEN
		SELECT Gid AS ordered FROM Medicines WHERE (Id = new.Mid) EXCEPT ALL 
			(SELECT Id AS Gid FROM GroupsOfDrugs WHERE (ReceipNeed = FALSE) 
				UNION SELECT Gid FROM GroupsInReceips where (Cid = new.Cid AND Did = new.Did)) as S;
		IF (ordered IS NOT NULL) THEN
			RAISE EXCEPTION 'not allowed by receip drug';
		END IF;
		SELECT Ccount INTO drugcnt FROM DrugstoresAmounts WHERE (Mid = new.Mid AND Did = new.Did);
		if (drugcnt IS NULL OR drugcnt.Ccount < new.Ccount) THEN
			RAISE EXCEPTION 'not enough drugs in shop';
		END IF; 		
	END IF;
	RETURN new;
END $$;
CREATE TRIGGER checkReceip BEFORE INSERT OR UPDATE ON OrdersAmounts FOR EACH ROW execute procedure checkReceip();


--Корректность наличия рецепта в заказе
CREATE OF REPLACE FUNCTION checkHasReceip() RETURNS TRIGGER language plpsql AS $$
DECLARE
	hasReceip record;
BEGIN
	IF (new.Cid IS NOT NULL AND new.Did IS NOT NULL AND new.Gid IS NOT NULL) THEN
		SELECT HasReceip INTO hasReceip FROM Orders WHERE (Cid = new.Cid AND Did = new.Did);
		IF (hasReceip.HasReceip = FALSE) THEN
			RAISE EXCEPTION 'customers without receip';
		END IF; 
	END IF;
	RETURN new;
END $$;
CREATE TRIGGER checkHasReceip BEFORE INSERT OR UPDATE ON GroupsInReceips FOR EACH ROW execute procedure checkHasReceip();


--ИНДЕКСЫ
CREATE INDEX DrugstoresIAR ON Drugstores(Id, Address, Requisites);
CREATE INDEX CustomersI ON Customers(Id);
CREATE INDEX ProvidersIN ON ProvidersIRN(Id, Name);
CREATE INDEX IllnessesIN ON Illnesses(Id, Name);
CREATE INDEX GroupsIN ON GroupsOfDrugs(Id, Name);
CREATE INDEX OrdersCD ON Orders(Cid, Did);
CREATE INDEX OrdersAmountsCDM ON OrdersAmounts(Cid, Did, Mid);
CREATE INDEX IllnessesOfCustomersCDI ON IllnessesOfCustomers(Cid, Did, Iid);
CREATE INDEX GroupsInReceipCDG ON GroupsInReceip(Cid, Did, Gid);
CREATE INDEX IndicationsMI ON Indications(Mid, Iid);
CREATE INDEX DeliveriesPD ON Deliveries(Pid, Did);
CREATE INDEX DeliveriesAmountsPMD ON DeliveriesAmounts(Pid, Mid, Did);
CREATE INDEX DrugstoresAmountsMD ON DrugstoresAmounts(Mid, Did);
CREATE INDEX MedicinesIGN ON Medicines(Id, Gid, Name);


--ТЕСТОВЫЕ ДАННЫЕ
INSERT INTO Drugstores(Id, Address, SignboardOutside, Requisites) VALUES
	(1, 'первый адрес', TRUE, '8854681325'),
	(2, 'второй адрес', FALSE, '8618242186');

INSERT INTO Illnesses(Id, Name, FullName) VALUES
	(1, 'болезнь 1', 'полное имя болезнь 1'),
	(2, 'болезнь 2', 'полное имя болезнь 2'),
	(3, 'болезнь 3', 'полное имя болезнь 3'),
	(4, 'болезнь 4', 'полное имя болезнь 4'),
	(5, 'болезнь 5', 'полное имя болезнь 5'),
	(6, 'болезнь 6', 'полное имя болезнь 6'),
	(7, 'болезнь 7', 'полное имя болезнь 7'),
	(8, 'болезнь 8', 'полное имя болезнь 8'),
	(9, 'болезнь 9', 'полное имя болезнь 9');

INSERT INTO GroupsOfDrugs(Id, Name, FullName, ReceipNeed) VALUES
	(1, 'группа 1', 'полное имя группы 1', FALSE),
	(2, 'группа 2', 'полное имя группы 2', FALSE),
	(3, 'группа 3', 'полное имя группы 3', TRUE),
	(4, 'группа 4', 'полное имя группы 4', TRUE),
	(5, 'группа 5', 'полное имя группы 5', TRUE);

INSERT INTO Medicines(Id, Name, FullName, Gid) VALUES
	(1, 'препарат 1', 'полное имя препарата 1', 1),
	(2, 'препарат 2', 'полное имя препарата 2', 1),
	(3, 'препарат 3', 'полное имя препарата 3', 2),
	(4, 'препарат 4', 'полное имя препарата 4', 1),
	(5, 'препарат 5', 'полное имя препарата 5', 4),
	(6, 'препарат 6', 'полное имя препарата 6', 2),
	(7, 'препарат 7', 'полное имя препарата 7', 3),
	(8, 'препарат 8', 'полное имя препарата 8', 5),
	(9, 'препарат 9', 'полное имя препарата 9', 5),
	(10, 'препарат 10', 'полное имя препарата 10', 1),
	(11, 'препарат 11', 'полное имя препарата 11', 2),
	(12, 'препарат 12', 'полное имя препарата 12', 3);
	
INSERT INTO Customers(Id, Requisites) VALUES
	(1, '8536394655'),
	(2, '4499437604'),
	(3, '6101148201'),
	(4, '8832253791'),
	(5, '3137250007'),
	(6, '4149589306');

INSERT INTO Providers(Id, Name, Requisites) VALUES
	(1, 'поставщик 1', '2562177947'),
	(2, 'поставщик 2', '9855215554'),
	(3, 'поставщик 3', '0749530749');

INSERT INTO Deliveries(Time, Pid, Did) VALUES
	('2013-01-01 15:20:00', 1, 1),
	('2013-04-01 15:05:00', 1, 2),
	('2013-02-01 13:30:00', 3, 2),
	('2014-01-01 12:40:00', 2, 1),
	('2014-10-01 12:40:00', 3, 1);

INSERT INTO DeliveriesAmounts(Pid, Did, Mid, Price, Ccount, Time) VALUES
	(1, 1, 1, 10, 100, '2013-01-01 15:20:00'),
	(1, 1, 2, 100, 100, '2013-01-01 15:20:00'),
	(1, 1, 3, 30, 100, '2013-01-01 15:20:00'),
	(1, 1, 4, 5, 100, '2013-01-01 15:20:00'),
	(1, 1, 5, 600, 100, '2013-01-01 15:20:00'),
	(1, 1, 6, 40, 100, '2013-01-01 15:20:00'),
	(1, 2, 1, 10, 70, '2013-04-01 15:05:00'),
	(1, 2, 2, 100, 70, '2013-04-01 15:05:00'),
	(1, 2, 3, 30, 70, '2013-04-01 15:05:00'),
	(1, 2, 4, 5, 70, '2013-04-01 15:05:00'),
	(1, 2, 5, 600, 70, '2013-04-01 15:05:00'),
	(1, 2, 6, 40, 70, '2013-04-01 15:05:00'),
	(3, 2, 7, 50, 20, '2013-02-01 13:30:00'),
	(3, 2, 8, 1000, 20, '2013-02-01 13:30:00'),
	(3, 2, 9, 1200, 20, '2013-02-01 13:30:00'),
	(3, 1, 7, 50, 20, '2014-10-01 12:40:00'),
	(3, 1, 8, 1000, 20, '2014-10-01 12:40:00'),
	(3, 1, 9, 1200, 20, '2014-10-01 12:40:00'),
	(2, 1, 10, 12, 100, '2014-10-01 12:40:00'),
	(2, 1, 11, 40, 100, '2014-10-01 12:40:00'),
	(2, 1, 12, 40, 100, '2014-10-01 12:40:00');

INSERT INTO DrugstoresAmounts(Did, Mid, Price, Ccount) VALUES
	(1, 1, 20, 97),
	(1, 2, 200, 100),
	(1, 3, 60, 100),
	(1, 4, 10, 100),
	(1, 5, 800, 100),
	(1, 6, 80, 100),
	(2, 1, 20, 70),
	(2, 2, 200, 70),
	(2, 3, 50, 70),
	(2, 4, 10, 70),
	(2, 5, 900, 67),
	(2, 6, 70, 70),
	(2, 7, 100, 20),
	(2, 8, 1500, 20),
	(2, 9, 1900, 20),
	(1, 7, 150, 20),
	(1, 8, 1600, 20),
	(1, 9, 1700, 20),
	(1, 10, 12, 100),
	(1, 11, 60, 100),
	(1, 12, 50, 100);

INSERT INTO Indications(Iid, Mid, Time, Method, Contraindications, Ccount) VALUES
	(1, 1, 'время приема 1', 'способ приема 1', 'противопоказания 1', 20),
	(2, 2, 'время приема 2', 'способ приема 2', 'противопоказания 2', 20),
	(3, 3, 'время приема 3', 'способ приема 3', 'противопоказания 3', 20),
	(4, 4, 'время приема 1', 'способ приема 4', 'противопоказания 4', 20),
	(5, 5, 'время приема 2', 'способ приема 1', 'противопоказания 5', 20),
	(1, 5, 'время приема 2', 'способ приема 1', 'противопоказания 5', 20),
	(6, 6, 'время приема 3', 'способ приема 2', 'противопоказания 6', 20),
	(7, 7, 'время приема 1', 'способ приема 3', 'противопоказания 7', 10),
	(8, 8, 'время приема 2', 'способ приема 4', 'противопоказания 8', 10),
	(9, 9, 'время приема 3', 'способ приема 1', 'противопоказания 9', 10),
	(1, 10, 'время приема 1', 'способ приема 2', 'противопоказания 10', 10),
	(2, 11, 'время приема 2', 'способ приема 3', 'противопоказания 11', 10),
	(3, 12, 'время приема 3', 'способ приема 4', 'противопоказания 12', 10);

INSERT INTO Orders(Cid, Did, Time, HasReceip) VALUES
	(1, 1, '2014-10-02 12:40:00', FALSE),
	(2, 1, '2014-10-02 12:40:00', FALSE),
	(3, 1, '2014-10-02 12:40:00', FALSE),
	(4, 2, '2014-10-02 12:40:00', TRUE),
	(5, 2, '2014-10-02 12:40:00', TRUE),
	(6, 2, '2014-10-02 12:40:00', TRUE);
	
INSERT INTO GroupsInReceips(Gid, Cid, Did, Time) VALUES
	(4, 4, 2, '2014-10-02 12:40:00'),
	(4, 5, 2, '2014-10-02 12:40:00'),
	(4, 6, 2, '2014-10-02 12:40:00');

INSERT INTO IllnessesOfCustomers(Iid, Cid, Did, Time) VALUES
	(1, 1, 1, '2014-10-02 12:40:00'),
	(1, 4, 2, '2014-10-02 12:40:00'),
	(1, 5, 2, '2014-10-02 12:40:00'),
	(1, 6, 2, '2014-10-02 12:40:00');	

INSERT INTO OrdersAmounts(Mid, Cid, Did, Time, Ccount) VALUES
	(1, 1, 1, '2014-10-02 12:40:00', 1),
	(1, 2, 1, '2014-10-02 12:40:00', 1),
	(1, 3, 1, '2014-10-02 12:40:00', 1),
	(5, 4, 2, '2014-10-02 12:40:00', 1),
	(5, 5, 2, '2014-10-02 12:40:00', 1),
	(5, 6, 2, '2014-10-02 12:40:00', 1);
