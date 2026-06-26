-- ============================================================================
-- GISMA University of Applied Sciences
-- B103 Databases & Big Data - Individual Project
-- E-Commerce Relational Database System
-- ============================================================================
-- This single script creates the database, tables, constraints, indexes,
-- stored procedures, triggers, sample data, and query examples for the
-- e-commerce domain.
-- Run this script in MySQL (or MariaDB) with a user that has CREATE privileges.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Environment setup
-- ---------------------------------------------------------------------------
DROP DATABASE IF EXISTS ecommerce_gisma;
CREATE DATABASE ecommerce_gisma;
USE ecommerce_gisma;

SET sql_safe_updates = 0;
SET GLOBAL local_infile = 1;

-- ---------------------------------------------------------------------------
-- 2. Table creation
-- ---------------------------------------------------------------------------
CREATE TABLE Customers (
    customer_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    phone_number VARCHAR(20),
    registration_date DATE,
    country VARCHAR(50)
);

CREATE TABLE Suppliers (
    supplier_id INT AUTO_INCREMENT PRIMARY KEY,
    supplier_name VARCHAR(100) NOT NULL,
    contact_name VARCHAR(50),
    phone VARCHAR(20),
    country VARCHAR(50)
);

CREATE TABLE Products (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    category VARCHAR(50),
    price DECIMAL(10, 2) NOT NULL,
    stock INT DEFAULT 0,
    supplier_id INT,
    FOREIGN KEY (supplier_id) REFERENCES Suppliers(supplier_id)
);

CREATE TABLE Orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    order_date DATE NOT NULL,
    total_amount DECIMAL(10, 2),
    o_status VARCHAR(20) DEFAULT 'Pending',
    customer_id INT,
    FOREIGN KEY (customer_id) REFERENCES Customers(customer_id)
);

CREATE TABLE Order_Details (
    order_detail_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT,
    product_id INT,
    quantity INT NOT NULL,
    price_each DECIMAL(10, 2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES Orders(order_id),
    FOREIGN KEY (product_id) REFERENCES Products(product_id)
);

CREATE TABLE Transactions (
    transaction_id INT AUTO_INCREMENT PRIMARY KEY,
    transaction_date DATE NOT NULL,
    payment_method VARCHAR(50),
    amount DECIMAL(10, 2) NOT NULL,
    order_id INT,
    FOREIGN KEY (order_id) REFERENCES Orders(order_id)
);

CREATE TABLE Order_Log (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT,
    customer_id INT,
    order_date DATE,
    total_amount DECIMAL(10, 2),
    log_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ---------------------------------------------------------------------------
-- 3. Indexes for performance
-- ---------------------------------------------------------------------------
CREATE INDEX idx_customer_name ON Customers(first_name);
CREATE INDEX idx_customer_email ON Customers(email);
CREATE INDEX idx_product_category ON Products(category);
CREATE INDEX idx_order_date ON Orders(order_date);
CREATE INDEX idx_order_customer ON Orders(customer_id);

-- ---------------------------------------------------------------------------
-- 4. Stored procedures
-- ---------------------------------------------------------------------------
DELIMITER //

-- Procedure: list all orders for a given customer
CREATE PROCEDURE GetCustomerOrders(IN p_customer_id INT)
BEGIN
    SELECT o.order_id, o.order_date, o.total_amount, o.o_status
    FROM Orders o
    WHERE o.customer_id = p_customer_id;
END //

-- Procedure: check if a product is in stock
CREATE PROCEDURE CheckStock(IN p_product_id INT, OUT p_status VARCHAR(50))
BEGIN
    DECLARE v_stock INT;
    SELECT stock INTO v_stock FROM Products WHERE product_id = p_product_id;
    IF v_stock > 0 THEN
        SET p_status = 'In Stock';
    ELSE
        SET p_status = 'Out of Stock';
    END IF;
END //

-- Procedure: process a payment transaction for an order
CREATE PROCEDURE ProcessOrderTransaction(
    IN p_order_id INT,
    IN p_payment_method VARCHAR(50),
    IN p_amount DECIMAL(10, 2)
)
BEGIN
    START TRANSACTION;
    INSERT INTO Transactions (order_id, transaction_date, payment_method, amount)
    VALUES (p_order_id, CURDATE(), p_payment_method, p_amount);
    UPDATE Orders SET o_status = 'Paid' WHERE order_id = p_order_id;
    COMMIT;
END //

-- Procedure: place an order, deduct stock, and create order details
CREATE PROCEDURE HandleOrder(
    IN p_order_id INT,
    IN p_product_id INT,
    IN p_quantity INT,
    IN p_price_each DECIMAL(10, 2)
)
BEGIN
    DECLARE v_stock INT;
    START TRANSACTION;
    SELECT stock INTO v_stock FROM Products WHERE product_id = p_product_id FOR UPDATE;
    IF v_stock >= p_quantity THEN
        UPDATE Products SET stock = stock - p_quantity WHERE product_id = p_product_id;
        INSERT INTO Order_Details (order_id, product_id, quantity, price_each)
        VALUES (p_order_id, p_product_id, p_quantity, p_price_each);
        UPDATE Orders
        SET total_amount = total_amount + (p_quantity * p_price_each)
        WHERE order_id = p_order_id;
        COMMIT;
    ELSE
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Insufficient stock for the requested product';
    END IF;
END //

-- Procedure: generate a large number of customers for index testing
CREATE PROCEDURE InsertCustomers()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 1000000 DO
        INSERT INTO Customers (first_name, last_name, email, phone_number, registration_date, country)
        VALUES (CONCAT('First', i), CONCAT('Last', i), CONCAT('user', i, '@example.com'), '0000000000', CURDATE(), 'TestCountry');
        SET i = i + 1;
    END WHILE;
END //

DELIMITER ;

-- ---------------------------------------------------------------------------
-- 5. Triggers
-- ---------------------------------------------------------------------------
DELIMITER //
CREATE TRIGGER log_order_insert
AFTER INSERT ON Orders
FOR EACH ROW
BEGIN
    INSERT INTO Order_Log (order_id, customer_id, order_date, total_amount)
    VALUES (NEW.order_id, NEW.customer_id, NEW.order_date, NEW.total_amount);
END //
DELIMITER ;

-- ---------------------------------------------------------------------------
-- 6. Sample data - single inserts
-- ---------------------------------------------------------------------------
INSERT INTO Customers (first_name, last_name, email, phone_number, registration_date, country)
VALUES ('John', 'Doe', 'johndoe@example.com', '1234567890', '2024-01-15', 'USA');

INSERT INTO Suppliers (supplier_name, contact_name, phone, country)
VALUES ('TechSupply', 'Jane Doe', '5551234567', 'USA');

INSERT INTO Products (product_name, category, price, stock, supplier_id)
VALUES ('Laptop', 'Electronics', 1200.00, 50, 1);

INSERT INTO Orders (customer_id, order_date, total_amount, o_status)
VALUES (1, '2024-11-01', 1200.00, 'Pending');

INSERT INTO Order_Details (order_id, product_id, quantity, price_each)
VALUES (1, 1, 1, 1200.00);

INSERT INTO Transactions (order_id, transaction_date, payment_method, amount)
VALUES (1, '2024-10-01', 'Credit Card', 1200.00);

-- ---------------------------------------------------------------------------
-- 7. Sample data - bulk inserts
-- ---------------------------------------------------------------------------
INSERT INTO Customers (first_name, last_name, email, phone_number, registration_date, country)
VALUES
('Alice', 'Brown', 'aliceb@example.com', '1111111111', '2024-02-10', 'UK'),
('Bob', 'Smith', 'bobsmith@example.com', '2222222222', '2024-03-25', 'Canada'),
('Charlie', 'Davis', 'charlied@example.com', '3333333333', '2024-05-30', 'Australia');

INSERT INTO Suppliers (supplier_name, contact_name, phone, country)
VALUES
('GadgetWorld', 'Susan Miller', '4444444444', 'France'),
('GlobalParts', 'Mark Johnson', '5555555555', 'Italy');

INSERT INTO Products (product_name, category, price, stock, supplier_id)
VALUES
('Smartphone', 'Electronics', 800.00, 30, 2),
('Tablet', 'Electronics', 600.00, 20, 3),
('Wireless Mouse', 'Accessories', 50.00, 100, 1);

INSERT INTO Orders (customer_id, order_date, total_amount, o_status)
VALUES
(2, '2024-11-05', 800.00, 'Delivered'),
(3, '2024-11-10', 600.00, 'Pending');

INSERT INTO Order_Details (order_id, product_id, quantity, price_each)
VALUES
(2, 2, 1, 800.00),
(3, 3, 1, 600.00);

INSERT INTO Transactions (order_id, transaction_date, payment_method, amount)
VALUES
(2, '2024-11-05', 'PayPal', 800.00),
(3, '2024-11-10', 'Debit Card', 600.00);

-- ---------------------------------------------------------------------------
-- 8. Load data from CSV files (optional)
-- Update the file paths below to point to the GISMA_Ecommerce_Data folder on your system.
-- In MySQL Workbench/CLI: SET GLOBAL local_infile = 1; and start the client with --local-infile=1.
-- ---------------------------------------------------------------------------
/*
LOAD DATA LOCAL INFILE '/Users/yash/Downloads/SQL Queries - Part-04/GISMA_Ecommerce_Data/customers.csv'
INTO TABLE Customers
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(customer_id, first_name, last_name, email, phone_number, registration_date, country);

LOAD DATA LOCAL INFILE '/Users/yash/Downloads/SQL Queries - Part-04/GISMA_Ecommerce_Data/orders.csv'
INTO TABLE Orders
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(order_id, order_date, total_amount, o_status, customer_id);

LOAD DATA LOCAL INFILE '/Users/yash/Downloads/SQL Queries - Part-04/GISMA_Ecommerce_Data/transactions.csv'
INTO TABLE Transactions
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(transaction_id, transaction_date, payment_method, amount, order_id);

LOAD DATA LOCAL INFILE '/Users/yash/Downloads/SQL Queries - Part-04/GISMA_Ecommerce_Data/suppliers.csv'
INTO TABLE Suppliers
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(supplier_id, supplier_name, contact_name, phone, country);

LOAD DATA LOCAL INFILE '/Users/yash/Downloads/SQL Queries - Part-04/GISMA_Ecommerce_Data/products.csv'
INTO TABLE Products
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(product_id, product_name, category, price, stock, supplier_id);

LOAD DATA LOCAL INFILE '/Users/yash/Downloads/SQL Queries - Part-04/GISMA_Ecommerce_Data/order_details.csv'
INTO TABLE Order_Details
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(order_detail_id, order_id, product_id, quantity, price_each);
*/

-- ---------------------------------------------------------------------------
-- 9. Demonstration queries
-- ---------------------------------------------------------------------------

-- 9.1 SELECT, aliases, and conditional logic
SELECT first_name AS 'First Name', last_name AS 'Last Name' FROM Customers;

SELECT orders.order_id AS Ids, orders.total_amount AS Amount,
       IF(total_amount > 100, 'High', 'Low') AS 'Order Type'
FROM Orders;

SELECT first_name, last_name, country,
       CASE
           WHEN country IN ('USA', 'Canada') THEN 'North America'
           WHEN country IN ('Germany', 'UK', 'France', 'Italy') THEN 'Europe'
           ELSE 'Other'
       END AS Region
FROM Customers;

-- 9.2 Aggregation and grouping
SELECT o_status AS 'Order Status', COUNT(*) AS 'Order Count'
FROM Orders
GROUP BY o_status;

SELECT category AS Category, ROUND(AVG(price), 2) AS 'Average Price'
FROM Products
GROUP BY category
HAVING AVG(price) > 20;

-- 9.3 INNER JOIN examples
SELECT c.customer_id, c.first_name, c.last_name, o.order_id, o.order_date, o.total_amount
FROM Customers c
INNER JOIN Orders o ON c.customer_id = o.customer_id;

SELECT p.product_id, p.product_name, s.supplier_name, s.country
FROM Products p
INNER JOIN Suppliers s ON p.supplier_id = s.supplier_id;

SELECT o.order_id, o.order_date, p.product_name, od.quantity, od.price_each
FROM Orders o
INNER JOIN Order_Details od ON o.order_id = od.order_id
INNER JOIN Products p ON od.product_id = p.product_id;

SELECT c.customer_id, c.first_name, c.last_name,
       SUM(od.quantity * od.price_each) AS total_spent
FROM Customers c
INNER JOIN Orders o ON c.customer_id = o.customer_id
INNER JOIN Order_Details od ON o.order_id = od.order_id
GROUP BY c.customer_id, c.first_name, c.last_name;

-- 9.4 LEFT JOIN - customers and their orders, including customers without orders
SELECT c.customer_id, c.first_name, c.last_name, o.order_id, o.order_date, o.total_amount
FROM Customers c
LEFT JOIN Orders o ON c.customer_id = o.customer_id;

-- 9.5 Identify inactive customers
SELECT c.customer_id, c.first_name, c.last_name
FROM Customers c
LEFT JOIN Orders o ON c.customer_id = o.customer_id
WHERE o.order_id IS NULL;

-- 9.6 RIGHT JOIN - suppliers and their products
SELECT p.product_id, p.product_name, s.supplier_name, s.contact_name
FROM Products p
RIGHT JOIN Suppliers s ON p.supplier_id = s.supplier_id;

-- 9.7 FULL OUTER JOIN (simulated with UNION because MySQL does not support FULL JOIN)
SELECT p.product_id, p.product_name, s.supplier_id, s.supplier_name
FROM Products p
LEFT JOIN Suppliers s ON p.supplier_id = s.supplier_id
UNION
SELECT p.product_id, p.product_name, s.supplier_id, s.supplier_name
FROM Products p
RIGHT JOIN Suppliers s ON p.supplier_id = s.supplier_id;

-- ---------------------------------------------------------------------------
-- 10. Update and delete examples
-- ---------------------------------------------------------------------------
-- Update a customer record
UPDATE Customers
SET email = 'newemail1@example.com', phone_number = '1234567890'
WHERE customer_id = 1;

-- Update a product price and stock
UPDATE Products
SET price = 1999.00, stock = 150
WHERE product_id = 1;

-- Delete a product (use with care because of foreign-key constraints)
-- DELETE FROM Products WHERE product_id = 35;

-- ---------------------------------------------------------------------------
-- 11. Stored procedure and trigger demonstrations
-- ---------------------------------------------------------------------------
CALL GetCustomerOrders(1);
CALL GetCustomerOrders(5);

SET @status = '';
CALL CheckStock(1, @status);
SELECT @status AS stock_status;

-- Place a new order and log it automatically via the trigger
INSERT INTO Orders (customer_id, order_date, total_amount, o_status)
VALUES (1, CURDATE(), 0.00, 'Pending');
SELECT * FROM Order_Log;

-- Use a transaction to place a full order with stock handling
CALL HandleOrder(LAST_INSERT_ID(), 1, 2, 50.00);

-- ---------------------------------------------------------------------------
-- 12. Locking examples (run these in separate sessions if you want to observe blocking)
-- ---------------------------------------------------------------------------
-- Transaction 1
START TRANSACTION;
SELECT * FROM Orders WHERE order_id = 1 FOR UPDATE;
UPDATE Orders SET o_status = 'Shipped' WHERE order_id = 1;
COMMIT;

-- Table-level lock
LOCK TABLES Orders WRITE;
INSERT INTO Orders (customer_id, order_date, total_amount, o_status)
VALUES (1, '2024-11-01', 1200.00, 'Pending');
UNLOCK TABLES;

-- ---------------------------------------------------------------------------
-- 13. Environment inspection
-- ---------------------------------------------------------------------------
SHOW INDEX FROM Customers;
SHOW INDEX FROM Orders;
SHOW TRIGGERS;
SHOW VARIABLES LIKE 'transaction_isolation';

-- ---------------------------------------------------------------------------
-- 14. Reset / test helpers (uncomment to use)
-- ---------------------------------------------------------------------------
/*
DELETE FROM Customers;
DELETE FROM Orders;
DELETE FROM Transactions;
DELETE FROM Suppliers;
DELETE FROM Products;
DELETE FROM Order_Details;
DELETE FROM Order_Log;
ALTER TABLE Customers AUTO_INCREMENT = 90;
*/
