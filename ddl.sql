--PostgreSQL
DROP DATABASE IF EXISTS DrugstoreBase;
CREATE DATABASE DrugstoreBase;


DROP TABLE IF EXISTS Drugstores CASCADE;
CREATE TABLE Drugstores(
	Id INT PRIMARY KEY,
	Address VARCHAR(50) NOT NULL,
	SignboardOutside boolean NOT NULL,
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
	IndicationMethod VARCHAR(1000) NOT NULL,
	Patented boolean NOT NULL,
	
	FOREIGN KEY (Gid) REFERENCES GroupsOfDrugs(Id) ON DELETE CASCADE
);

DROP TABLE IF EXISTS IndicationsForIllnesses CASCADE;
CREATE TABLE IndicationsForIllnesses(
	Mid INT,
	Iid INT,

	PRIMARY KEY (Mid, Iid),
	FOREIGN KEY (Mid) REFERENCES Medicines(Id) ON DELETE CASCADE,
	FOREIGN KEY (Iid) REFERENCES Illnesses(Id) ON DELETE CASCADE
);

DROP TABLE IF EXISTS Orders CASCADE;
CREATE TABLE Orders(
	Did INT,
	LocalId INT,
	Time TIMESTAMP NOT NULL, 
	Rejected boolean NOT NULL,
	
	
	PRIMARY KEY (Did, LocalId),
	FOREIGN KEY (Did) REFERENCES Drugstores(Id) ON DELETE CASCADE
);

DROP TABLE IF EXISTS DrugArrangements CASCADE;
CREATE TABLE DrugArrangements(
	Id INT PRIMARY KEY,
	Form varchar(50) NOT NULL,
	AIWPI REAL NOT NULL CHECK (AIWPI > 0),
	ItemsInBox INT NOT NULL CHECK (ItemsInBox > 0),
	Mid INT NOT NULL,
	
	FOREIGN KEY (Mid) REFERENCES Medicines(Id) ON DELETE CASCADE		
);

DROP TABLE IF EXISTS OrdersAmounts CASCADE;
CREATE TABLE OrdersAmounts(
	Aid INT,
	LocalId INT,
	Did INT,
	Ccount INT NOT NULL CHECK (Ccount > 0),
	
	PRIMARY KEY (Aid, LocalId, Did),
	FOREIGN KEY (Aid) REFERENCES DrugArrangements(Id) ON DELETE CASCADE,
	FOREIGN KEY (Did, LocalId) REFERENCES Orders(Did, LocalId) ON DELETE CASCADE
);

DROP TABLE IF EXISTS StoresAmounts CASCADE;
CREATE TABLE StoresAmounts(
	Aid INT,
	Did INT,
	Ccount INT NOT NULL CHECK (Ccount > 0),
	Price REAL NOT NULL CHECK (Price > 0),

	PRIMARY KEY (Aid, Did),
	FOREIGN KEY (Aid) REFERENCES DrugArrangements(Id) ON DELETE CASCADE,
	FOREIGN KEY (Did) REFERENCES Drugstores(Id) ON DELETE CASCADE
);

DROP TABLE IF EXISTS IllnessesOfCustomers CASCADE;
CREATE TABLE IllnessesOfCustomers(
	Iid INT,
	LocalId INT,
	Did INT,
	
	PRIMARY KEY (Iid, LocalId, Did),
	FOREIGN KEY (Iid) REFERENCES Illnesses(Id) ON DELETE CASCADE,
	FOREIGN KEY (Did, LocalId) REFERENCES Orders(Did, LocalId) ON DELETE CASCADE
);
	
DROP TABLE IF EXISTS GroupsInReceips CASCADE;
CREATE TABLE GroupsInReceips(
	Gid INT,
	LocalId INT,
	Did INT,
	
	PRIMARY KEY (Gid, LocalId, Did),
	FOREIGN KEY (Gid) REFERENCES GroupsOfDrugs(Id) ON DELETE CASCADE,
	FOREIGN KEY (Did, LocalId) REFERENCES Orders(Did, LocalId) ON DELETE CASCADE
);

--ТРИГГЕРЫ
--Покупатель имеет право приобретать разрешенные группы медикаментов
--при этом может купить не больше доступного количества
CREATE OR REPLACE FUNCTION checkReceipForAmount() RETURNS TRIGGER language plpgsql AS $$
DECLARE
	ordered record;
	drugcnt record;
BEGIN
	IF (new.LocalId IS NOT NULL AND new.Did IS NOT NULL AND new.Aid IS NOT NULL AND new.Ccount IS NOT NULL) THEN
		SELECT Gid INTO	ordered FROM 
			(SELECT	Gid FROM 
				(SELECT Mid AS Id FROM DrugArrangements WHERE (Id = new.Aid)) AS NN
				NATURAL JOIN Medicines)	AS BB
		EXCEPT ALL 
			(SELECT Id AS Gid FROM GroupsOfDrugs WHERE (ReceipNeed = FALSE)
			UNION SELECT Gid FROM GroupsInReceips WHERE (LocalId = new.LocalId AND Did = new.Did));
		IF (ordered IS NOT NULL) THEN
			RAISE EXCEPTION 'not allowed by receip drug';
		END IF;
		SELECT Ccount INTO drugcnt FROM StoresAmounts WHERE (Aid = new.Aid AND Did = new.Did);
		if (drugcnt IS NULL OR drugcnt.Ccount < new.Ccount) THEN
			RAISE EXCEPTION 'not enough drugs in shop';
		END IF; 		
	END IF;
	RETURN new;
END $$;
CREATE TRIGGER checkReceipForAmount BEFORE INSERT OR UPDATE ON OrdersAmounts FOR EACH ROW execute procedure checkReceipForAmount();


--ИНДЕКСЫ
--для поиска по адресу (или названию) и его префиксу
CREATE INDEX DrugstoresA ON Drugstores(Address);
CREATE INDEX GroupsOfDrugsN ON GroupsOfDrugs(Name);
CREATE INDEX IllnessesN ON Illnesses(Name);
CREATE INDEX MedicinesN ON Medicines(Name);

--для ускорения запросов
--имеет хорошую селективность
CREATE INDEX DrugArrangementsM ON DrugArrangements(Mid);
--за счет сильной разреженности (покупатели обычно без рецепта и указания болезней)
CREATE INDEX GroupsInReceipsL ON GroupsInReceips(LocalId);
CREATE INDEX IllnessesOfCustomersL ON IllnessesOfCustomers(LocalId);
--среднюю селективность
CREATE INDEX OrdersL ON Orders(LocalId);
CREATE INDEX StoresAmountsA ON StoresAmounts(Aid);
CREATE INDEX IndicationsForIllnessesI ON IndicationsForIllnesses(Iid);


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

INSERT INTO Medicines(Id, Name, FullName, Gid, IndicationMethod, Patented) VALUES
	(1, 'препарат 1', 'полное имя препарата 1', 1, '', TRUE),
	(2, 'препарат 2', 'полное имя препарата 2', 1, '', TRUE),
	(3, 'препарат 3', 'полное имя препарата 3', 2, '', TRUE),
	(4, 'препарат 4', 'полное имя препарата 4', 1, '', TRUE),
	(5, 'препарат 5', 'полное имя препарата 5', 4, '', TRUE),
	(6, 'препарат 6', 'полное имя препарата 6', 2, '', TRUE),
	(7, 'препарат 7', 'полное имя препарата 7', 3, '', TRUE),
	(8, 'препарат 8', 'полное имя препарата 8', 5, '', TRUE),
	(9, 'препарат 9', 'полное имя препарата 9', 5, '', TRUE),
	(10, 'препарат 10', 'полное имя препарата 10', 1, '', TRUE),
	(11, 'препарат 11', 'полное имя препарата 11', 2, '', TRUE),
	(12, 'препарат 12', 'полное имя препарата 12', 3, '', TRUE);

INSERT INTO DrugArrangements(Id, Form, AIWPI, ItemsInBox, Mid) VALUES
	(1, 'ф 1', 1, 1, 1),
	(2, 'ф 2', 1, 1, 2),
	(3, 'ф 3', 1, 2, 3),
	(4, 'ф 4', 1, 1, 4),
	(5, 'ф 5', 1, 4, 5),
	(6, 'ф 6', 1, 2, 6),
	(7, 'ф 7', 1, 3, 7),
	(8, 'ф 8', 1, 5, 8),
	(9, 'ф 9', 1, 5, 9),
	(10, 'ф 10', 1, 1, 10),
	(11, 'ф 11', 1, 2, 11),
	(12, 'ф 12', 1, 3, 12);


INSERT INTO StoresAmounts(Did, Aid, Price, Ccount) VALUES
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

INSERT INTO IndicationsForIllnesses(Iid, Mid) VALUES
	(1, 1),
	(2, 2),
	(3, 3),
	(4, 4),
	(5, 5),
	(1, 5),
	(6, 6),
	(7, 7),
	(8, 8),
	(9, 9),
	(1, 10),
	(2, 11),
	(3, 12);

INSERT INTO Orders(Localid, Did, Time, Rejected) VALUES
	(1, 1, '2014-10-02 12:40:00', TRUE),
	(2, 1, '2014-10-02 12:40:00', TRUE),
	(3, 1, '2014-10-02 12:40:00', FALSE),
	(1, 2, '2014-10-02 12:40:00', FALSE),
	(2, 2, '2014-10-02 12:40:00', FALSE),
	(3, 2, '2014-10-02 12:40:00', FALSE);
	
INSERT INTO GroupsInReceips(Gid, LocalId, Did) VALUES
	(4, 1, 2),
	(4, 2, 2),
	(4, 3, 2);

INSERT INTO IllnessesOfCustomers(Iid, LocalId, Did) VALUES
	(1, 1, 1),
	(1, 3, 1),
	(1, 1, 2),
	(1, 2, 2),
	(1, 3, 2);	


INSERT INTO OrdersAmounts(Aid, Localid, Did, Ccount) VALUES
	(1, 1, 1, 1),
	(1, 2, 1, 1),
	(1, 3, 1, 1),
	(5, 1, 2, 1),
	(5, 2, 2, 1),
	(5, 3, 2, 1);
INSERT INTO OrdersAmounts(Aid, Localid, Did, Ccount) VALUES
	(5, 1, 1, 1);
INSERT INTO OrdersAmounts(Aid, Localid, Did, Ccount) VALUES
	(2, 2, 1, 10000);
	

--1)все препараты по заданной группе
DROP FUNCTION IF EXISTS getDrugsByGroup(INT);
CREATE FUNCTION getDrugsByGroup(_Gid INT) RETURNS TABLE(Id INT, Form varchar(50)) as $$
BEGIN
	RETURN query (SELECT Aid AS Id, Form FROM 
		(SELECT Aid, Form FROM 
			(SELECT Id AS Mid FROM Medicines WHERE Medicines.Gid = _Gid) AS SS 
			NATURAL JOIN DrugArrangements
			NATURAL JOIN StoresAmounts) as AA);
END;
$$ language plpgsql;

--2)все препараты по заданной болезни
DROP FUNCTION IF EXISTS getDrugsByIllness(INT);
CREATE FUNCTION getDrugsByIllness(_Iid INT) RETURNS TABLE(Id INT, Form varchar(50)) as $$
BEGIN
	RETURN query (SELECT Aid AS Id, Form FROM 
		(SELECT Aid, Form FROM 
			(SELECT Mid FROM IndicationsForIllness WHERE 
				IndicationsForIllness.Iid = _Iid) AS SS 
			NATURAL JOIN DrugArrangements
			NATURAL JOIN StoresAmounts) AS AA);
END;
$$ language plpgsql;

--3)наиболее популярный препарат для каждой болезни, в каком отделении в наличии по меньшей цене
SELECT DISTINCT ON (Iid) 
	Iid, Aid, Price, Address
FROM
	(SELECT DISTINCT ON (Iid) 
	    Iid, Aid
	FROM 
		(SELECT 
			Iid, Aid, SUM(Ccount) AS Total
		FROM 
			Orders
			NATURAL JOIN IllnessesOfCustomers
 			NATURAL JOIN OrdersAmounts
		WHERE (Rejected = FALSE)
		GROUP BY 
			Iid, Aid) AS Counts 
	ORDER BY 
    		iid, Total DESC) AS Maxes
	NATURAL JOIN
		(SELECT 
			Aid, Did AS ID, Price 
		FROM
			StoresAmounts
		WHERE
			(Ccount > 0)) AS Stores
	NATURAL JOIN
		Drugstores
ORDER BY
	Iid, Price;
