--PostgreSQL
DROP DATABASE IF EXISTS DrugstoreBase;
CREATE DATABASE DrugstoreBase;
\c DrugstoreBase

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
CREATE TABLE Indications(
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
	AIWPI REAL NOT NULL,
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

DROP TABLE IF EXISTS IllnessesOfCustomes CASCADE;
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
CREATE OR REPLACE FUNCTION checkReceipForAmount() RETURNS TRIGGER language plpsql AS $$
DECLARE
	ordered record;
	drugcnt record;
BEGIN
	IF (new.LocalId IS NOT NULL AND new.Did IS NOT NULL AND new.Aid IS NOT NULL AND new.Ccount IS NOT NULL) THEN
		SELECT Gid INTO ordered FROM 
			(SELECT Gid FROM (SELECT Id AS Mid FROM DrugArrangements WHERE (Id = new.Aid)) AS NN
				NARUTAL JOIN Medicines) AS AA) AS BB
			EXCEPT ALL 
			(SELECT Id AS Gid FROM GroupsOfDrugs WHERE (ReceipNeed = FALSE) 
				UNION SELECT Gid FROM GroupsInReceips where (Cid = new.Cid AND Did = new.Did)) as SS;
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
