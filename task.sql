--5 работа с представлениями
--узнать какой препарат наиболее популярен для болезни и где он дешевле всего стоит

CREATE VIEW CheapAndPopular AS
SELECT 
	Iid, Aid, Did, MIN(Price)
FROM
	SELECT 
		Iid, Aid, Did, Price
	FROM
		(SELECT
			Iid, Aid, MAX(Total)
		FROM
			(SELECT 
				Iid, Id AS Aid, SUM(Ccount) AS Total
			FROM 
				IllnessesOfCustomers, IndicationsForIllnesses, OrdersAmounts, DrugArrangements
			GROUP BY 
				Iid, Aid) AS AA
		GROUP BY
			Iid, Total) AS BB
	NATURAL JOIN StoresAmounts
GROUP BY
	Iid, Aid;
