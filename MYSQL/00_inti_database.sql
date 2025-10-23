/*
=============================================================
Create Database and Schemas
=============================================================
Script Purpose:
    This script creates a new database named 'DataWarehouseAnalytics' after checking if it already exists. 
    If the database exists, it is dropped and recreated. Additionally, this script creates a schema called gold
	
WARNING:
    Running this script will drop the entire 'DataWarehouseAnalytics' database if it exists. 
    All data in the database will be permanently deleted. Proceed with caution 
    and ensure you have proper backups before running this script.

IMPORTANT - CSV FILE PATHS:
    Before running this script, you MUST update the file paths in the LOAD DATA INFILE statements below
    to match your local directory structure. 
    
    Current paths are set to: '/path/to/datasets/csv-files/'
    
    Change these paths to where YOUR CSV files are located on your machine.
    Example alternative paths:
        - Linux/Mac: '/home/username/datasets/csv-files/'
        - Windows (using forward slashes): 'C:/sql/sql-data-analytics-project/datasets/csv-files/'
    
    Required CSV files:
        1. gold.dim_customers.csv
        2. gold.dim_products.csv
        3. gold.fact_sales.csv

IMPORTANT - MySQL Configuration:
    For LOAD DATA INFILE to work, you may need to:
    1. Set the 'local_infile' variable to ON:
       SET GLOBAL local_infile = 1;
    2. Use LOAD DATA LOCAL INFILE instead of LOAD DATA INFILE
    3. Ensure MySQL has permission to read files from the specified directory
*/

-- Drop and recreate the 'DataWarehouseAnalytics' database
DROP DATABASE IF EXISTS DataWarehouseAnalytics;

-- Create the 'DataWarehouseAnalytics' database
CREATE DATABASE DataWarehouseAnalytics;

USE DataWarehouseAnalytics;

-- Create Tables (MySQL doesn't have schemas like SQL Server, so we prefix table names)

CREATE TABLE gold_dim_customers(
	customer_key INT,
	customer_id INT,
	customer_number VARCHAR(50),
	first_name VARCHAR(50),
	last_name VARCHAR(50),
	country VARCHAR(50),
	marital_status VARCHAR(50),
	gender VARCHAR(50),
	birthdate DATE,
	create_date DATE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE gold_dim_products(
	product_key INT,
	product_id INT,
	product_number VARCHAR(50),
	product_name VARCHAR(50),
	category_id VARCHAR(50),
	category VARCHAR(50),
	subcategory VARCHAR(50),
	maintenance VARCHAR(50),
	cost INT,
	product_line VARCHAR(50),
	start_date DATE 
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE gold_fact_sales(
	order_number VARCHAR(50),
	product_key INT,
	customer_key INT,
	order_date DATE,
	shipping_date DATE,
	due_date DATE,
	sales_amount INT,
	quantity TINYINT,
	price INT 
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- DATA LOADING SECTION
-- ============================================================
-- UPDATE THE FILE PATHS BELOW TO MATCH YOUR LOCAL DIRECTORY
-- ============================================================

TRUNCATE TABLE gold_dim_customers;

LOAD DATA LOCAL INFILE '/path/to/datasets/csv-files/gold.dim_customers.csv'  -- CHANGE THIS PATH
INTO TABLE gold_dim_customers
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

TRUNCATE TABLE gold_dim_products;

LOAD DATA LOCAL INFILE '/path/to/datasets/csv-files/gold.dim_products.csv'  -- CHANGE THIS PATH
INTO TABLE gold_dim_products
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

TRUNCATE TABLE gold_fact_sales;

LOAD DATA LOCAL INFILE '/path/to/datasets/csv-files/gold.fact_sales.csv'  -- CHANGE THIS PATH
INTO TABLE gold_fact_sales
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;