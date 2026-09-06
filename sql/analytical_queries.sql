-- ============================================================
-- WEEK 8 CAPSTONE
-- GLOBAL DIGITAL CONNECTIVITY OPPORTUNITY ANALYSIS
-- ============================================================
-- STEP 1: Create the database
-- ============================================================

CREATE DATABASE GlobalDigitalConnectivity;
USE GlobalDigitalConnectivity;


-- ============================================================
-- STEP 2: Create the table for our cleaned analytical data
-- ============================================================
-- Python has already cleaned and filtered the WDI dataset.
-- We are now creating a table in MySQL so we can use SQL
-- to answer our six analytical questions.
-- ============================================================

DROP TABLE IF EXISTS WDI_Technology_Africa;

CREATE TABLE WDI_Technology_Africa
(
    CountryName VARCHAR(150) CHARACTER SET utf8mb4,
    CountryCode VARCHAR(10),
    IndicatorName VARCHAR(200) CHARACTER SET utf8mb4,
    IndicatorCode VARCHAR(30),
    `Year` INT,
    Value_Raw VARCHAR(50),
    Region VARCHAR(100) CHARACTER SET utf8mb4,
    IncomeGroup VARCHAR(100) CHARACTER SET utf8mb4
);
DESCRIBE WDI_Technology_Africa;

-- ============================================================
-- STEP 3: LOAD THE CLEANED CSV INTO MYSQL
-- ============================================================
-- The CSV was prepared in Python.
-- We now bring those 3,975 cleaned observations into MySQL.
-- ============================================================

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/WDI_Technology_Africa_Final.csv'
INTO TABLE WDI_Technology_Africa
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    CountryName,
    CountryCode,
    IndicatorName,
    IndicatorCode,
    `Year`,
    Value_Raw,
    Region,
    IncomeGroup
);
SELECT *
FROM WDI_Technology_Africa
LIMIT 10;

SELECT
    COUNT(*) AS Total_Rows,
    COUNT(Value_Raw) AS Non_Null_Values,
    SUM(Value_Raw = '') AS Blank_Values
FROM WDI_Technology_Africa;

-- ============================================================
-- STEP 4: Create the final analysis table
-- ============================================================

CREATE TABLE wdi_technology_africa_clean AS
SELECT
    CountryName,
    CountryCode,
    IndicatorName,
    IndicatorCode,
    `Year`,
    CAST(Value_Raw AS DECIMAL(20,10)) AS `Value`,
    Region,
    IncomeGroup
FROM WDI_Technology_Africa;

-- ============================================================
-- ANALYTICAL QUESTIONS
-- ============================================================

### Q1. How has digital technology adoption changed across African countries over time?
SELECT
    Year,
    IndicatorName,
    AVG(Value) AS Average_Value
FROM WDI_Technology_Africa_Clean
GROUP BY Year, IndicatorName
ORDER BY Year, IndicatorName;

### Q2. Which African countries had the highest and lowest internet adoption in 2024?
### (2a)
    SELECT
        CountryName,
        ROUND(Value, 2) AS Internet_Adoption_2024
    FROM WDI_Technology_Africa_Clean
    WHERE IndicatorName = 'Individuals using the Internet (% of population)'
      AND Year = 2024
    ORDER BY Value DESC
    LIMIT 5;
    
### (2b)
    SELECT
        CountryName,
        ROUND(Value, 2) AS Internet_Adoption_2024
    FROM WDI_Technology_Africa_Clean
    WHERE IndicatorName = 'Individuals using the Internet (% of population)'
      AND Year = 2024
    ORDER BY Value ASC
    LIMIT 5;

### Q3. Which African countries experienced the largest increase in internet adoption between 2000 and 2024?
SELECT
    CountryName,
    MAX(CASE WHEN Year = 2000 THEN Value END) AS Internet_2000,
    MAX(CASE WHEN Year = 2024 THEN Value END) AS Internet_2024,
    MAX(CASE WHEN Year = 2024 THEN Value END)
      - MAX(CASE WHEN Year = 2000 THEN Value END) AS Increase_Percentage_Points
FROM WDI_Technology_Africa_Clean
WHERE IndicatorName = 'Individuals using the Internet (% of population)'
  AND Year IN (2000, 2024)
GROUP BY CountryName
HAVING Internet_2000 IS NOT NULL
   AND Internet_2024 IS NOT NULL
ORDER BY Increase_Percentage_Points DESC;

### Q4. Which African countries have relatively high mobile connectivity but lower internet adoption?
WITH african_medians AS (
    SELECT
        (
            SELECT AVG(Value)
            FROM (
                SELECT Value,
                       ROW_NUMBER() OVER (ORDER BY Value) AS rn,
                       COUNT(*) OVER () AS cnt
				FROM WDI_Technology_Africa_Clean
                WHERE IndicatorName = 'Mobile cellular subscriptions (per 100 people)'
                  AND Year = 2024
            ) AS mobile
            WHERE rn IN ((cnt + 1) / 2, (cnt + 2) / 2)
        ) AS mobile_median,
        (
            SELECT AVG(Value)
            FROM (
                SELECT Value,
                       ROW_NUMBER() OVER (ORDER BY Value) AS rn,
                       COUNT(*) OVER () AS cnt
                FROM WDI_Technology_Africa_Clean
                WHERE IndicatorName = 'Individuals using the Internet (% of population)'
                  AND Year = 2024
            ) AS internet
            WHERE rn IN ((cnt + 1) / 2, (cnt + 2) / 2)
        ) AS internet_median
)
SELECT
    d.CountryName,
    MAX(CASE
        WHEN d.IndicatorName = 'Mobile cellular subscriptions (per 100 people)'
        THEN d.Value END) AS Mobile_Subscriptions,
    MAX(CASE
        WHEN d.IndicatorName = 'Individuals using the Internet (% of population)'
        THEN d.Value END) AS Internet_Adoption,
    m.mobile_median AS African_Mobile_Median,
    m.internet_median AS African_Internet_Median
FROM WDI_Technology_Africa_Clean d
CROSS JOIN african_medians m
WHERE d.Year = 2024
  AND d.IndicatorName IN (
      'Mobile cellular subscriptions (per 100 people)',
      'Individuals using the Internet (% of population)'
  )
GROUP BY d.CountryName, m.mobile_median, m.internet_median
HAVING Mobile_Subscriptions > m.mobile_median
   AND Internet_Adoption < m.internet_median
ORDER BY Mobile_Subscriptions DESC;

###Q5. Which 10 African countries experienced the greatest improvement in digital connectivity over time? 

WITH changes AS (
    SELECT
        CountryName,
        IndicatorName,
        MAX(CASE WHEN Year = 2000 THEN Value END) AS Value_2000,
        MAX(CASE WHEN Year = 2024 THEN Value END) AS Value_2024
    FROM WDI_Technology_Africa_Clean
	WHERE Year IN (2000, 2024)
    GROUP BY CountryName, IndicatorName
)
SELECT
    CountryName,
    SUM(
        CASE
            WHEN Value_2000 IS NOT NULL
             AND Value_2024 IS NOT NULL
            THEN Value_2024 - Value_2000
            ELSE 0
        END
    ) AS Total_Digital_Improvement,
    COUNT(
        CASE
            WHEN Value_2000 IS NOT NULL
             AND Value_2024 IS NOT NULL
            THEN 1
        END
    ) AS Indicators_Compared
FROM changes
GROUP BY CountryName
HAVING Indicators_Compared > 0
ORDER BY Total_Digital_Improvement DESC;

###Q6. Which 5 African countries had the highest fixed broadband subscription rates in 2024?
SELECT
    CountryName,
    ROUND(Value, 2) AS Fixed_Broadband_2024
FROM WDI_Technology_Africa_Clean
WHERE IndicatorName = 'Fixed broadband subscriptions (per 100 people)'
  AND Year = 2024
ORDER BY Value DESC
LIMIT 5;

### Download the Wdi_Technology_Africa_Clean dataset

SELECT
    CountryName,
    CountryCode,
    IndicatorName,
    IndicatorCode,
    Year,
    Value,
    Region,
    IncomeGroup
FROM Wdi_Technology_Africa_Clean
ORDER BY CountryName, IndicatorName, Year;

