/* Creating a relational database and saving it into a new table */

SELECT loan_balance.["balance"], loan_balance.["dpd"],loan_type.["loan_type"],loan_balance.["loan_id"]
INTO loan_type_balance
FROM loan_balance 
INNER JOIN loan_type
ON (loan_balance.["loan_id"] = loan_type.["loan_id"]);

/* 1. Calculate and display the total balance for each Loan Type */

SELECT loan_type_balance.["loan_type"],
SUM(CAST(loan_type_balance.["balance"] as FLOAT)) AS 'Total Balance'
FROM loan_type_balance
GROUP BY loan_type_balance.["loan_type"]


/* 2. Convert the variable DPD to a numeric type and set the value of DPD to 0 if the value is missing, otherwise keep the value of DPD */ 

ALTER TABLE loan_type_balance ADD DPD int;
UPDATE loan_type_balance
SET DPD = CAST(REPLACE(["dpd"],'"','') AS int);

ALTER TABLE loan_type_balance
DROP COLUMN ["dpd"];

/* 3. Calculate a field called Stage based on the following criteria: 
    - Assign a value of "Stage 1" if the DPD variable is from 0 to 30
	- Assign a value of "Stage 2" if the DPD variable is from 31 to 90
    - Assign a value of "Stage 3" if the DPD variable is greater than or equal to 91.  */

ALTER TABLE loan_type_balance ADD Stage varchar(50);
UPDATE loan_type_balance
SET Stage = CASE
    WHEN DPD <= 30 THEN 'Stage 1'
    WHEN DPD BETWEEN 31 AND 90 THEN 'Stage 2'
    WHEN DPD >= 91 THEN 'Stage 3'
END;

SELECT * 
FROM loan_type_balance

/* 4. Calculate and display the total balance for each Loan Type by Stage (Stage 1, Stage 2, Stage 3) */

SELECT loan_type_balance.["loan_type"], loan_type_balance.Stage,
SUM(CAST(loan_type_balance.["balance"] as FLOAT)) AS 'Total Balance'
FROM loan_type_balance
GROUP BY loan_type_balance.["loan_type"], loan_type_balance.Stage 
ORDER BY loan_type_balance.["loan_type"], loan_type_balance.Stage;

/* 5. Calculate a field called ECL in the Balance File for each account using the following formula:
		- For Stage 1 Loans
			Multiply the 1-year PD for the loan type by the LGD for the loan type times the Balance on the Loan
		- For Stage 2 Loans
			Multiply the Lifetime PD for the loan type by the LGD for the loan type times the Balance on the Loan
		- For Stage 3 Loans
			Multiply the LGD for the loan type times the Balance on the Loan  */


SELECT ['PD file$'].*, ['LGD file$'].LGD
INTO loan_type_rates
FROM ['LGD file$']
INNER JOIN ['PD file$']
ON ['PD file$'].loan_type = ['LGD file$'].loan_type
 
 
SELECT loan_type_balance.["balance"],loan_type_balance.["loan_id"], loan_type_balance.DPD, loan_type_balance.ECL, loan_type_balance.Stage, REPLACE(loan_type_balance.["loan_type"],'"','') AS loan_type, loan_type_rates.[1_year_PD], loan_type_rates.LGD, loan_type_rates.Lifetime_PD
INTO loan_info
FROM loan_type_balance
LEFT OUTER JOIN loan_type_rates
ON REPLACE(loan_type_balance.["loan_type"],'"','') = loan_type_rates.loan_type


UPDATE loan_info
SET ECL = CASE
    WHEN loan_info.Stage = 'Stage 1' 
		THEN (loan_info.[1_year_PD] * loan_info.[LGD] * CAST(loan_info.["balance"] AS float))
    WHEN loan_info.Stage = 'Stage 2' 
		THEN (loan_info.[Lifetime_PD] * loan_info.[LGD]* CAST(loan_info.["balance"] AS float))
    WHEN loan_info.Stage = 'Stage 3' 
		THEN (loan_info.[LGD]* CAST(loan_info.["balance"] AS float))
END



/* 6. Calculate and display the total balance and the total ECL for each Loan Type */

SELECT loan_info.loan_type,
SUM(CAST(loan_info.["balance"] as FLOAT)) AS 'Total Balance', SUM(loan_info.ECL) AS 'Total ECL'
FROM loan_info
GROUP BY loan_info.loan_type 
ORDER BY loan_info.loan_type


/* 7. Calculate and display the total balance and total ECL for each Loan Type by Stage(Stage1, Stage 2, Stage 3) */

SELECT loan_info.loan_type, loan_info.Stage,
SUM(CAST(loan_info.["balance"] as FLOAT)) AS 'Total Balance', SUM(loan_info.ECL) AS 'Total ECL'
FROM loan_info
GROUP BY loan_info.loan_type, loan_info.Stage
ORDER BY loan_info.loan_type, loan_info.Stage



/* 8. Calculate and display the total coverage ratio (Total ECL divided by Total Balance) for each Loan Type by Stage (Stage 1, Stage 2, Stage 3) */

SELECT loan_info.loan_type, loan_info.Stage,
SUM(loan_info.ECL) / SUM(CAST(loan_info.["balance"] as FLOAT)) AS 'Total Coverage Ratio'
FROM loan_info
GROUP BY loan_info.loan_type, loan_info.Stage
ORDER BY loan_info.loan_type, loan_info.Stage



