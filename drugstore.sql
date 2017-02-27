--1)все препараты по заданной группе
DROP FUNCTION IF EXISTS getDrugsByGroup(INT);
CREATE FUNCTION getDrugsByGroup(_Gid INT) RETURNS TABLE(Id INT, Form varchar(50)) as $$
BEGIN
	RETURN query (SELECT Aid AS Id, Form FROM 
		SELECT Aid, Form FROM 
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
		SELECT Aid, Form FROM 
			(SELECT Mid FROM IndicationsForIllness WHERE 
				IndicationsForIllness.Iid = _Iid) AS SS 
			NATURAL JOIN DrugArrangements
			NATURAL JOIN StoresAmounts) as AA);
END;
$$ language plpgsql;


