```sql
-- schema_design.sql
-- Enhanced SQL schema for a simple Financial Transaction Tracking System.
-- This version is expanded for a company demo project, including:
-- - The core three tables: Customers, Accounts, and Transactions.
-- - Additional features for demo purposes:
--   - A Users table for basic authentication (e.g., bank staff managing the system).
--   - Views for common reports (e.g., customer account summaries, recent transactions).
--   - Triggers to automatically update account balances on deposits/withdrawals/transfers.
--   - Stored procedures for safe transaction operations (deposit, withdraw, transfer).
--   - Sample data population for demo testing.
--   - Additional indexes and constraints for performance and data integrity.
-- Assumptions:
-- - Using MySQL 8.0+ or PostgreSQL-compatible syntax (adjust for other DBMS if needed, e.g., SERIAL for auto-increment in PostgreSQL).
-- - Monetary values use DECIMAL(15, 2) for larger scales (up to billions).
-- - Transactions handle basic transfers (debit one account, credit another).
-- - Security: Passwords are hashed (in a real system, use proper hashing like bcrypt).
-- - For demo: No advanced security like encryption or auditing.

-- Drop tables if they exist (for clean demo setup; remove in production)
DROP TABLE IF EXISTS Transactions;
DROP TABLE IF EXISTS Accounts;
DROP TABLE IF EXISTS Customers;
DROP TABLE IF EXISTS Users;
DROP VIEW IF EXISTS CustomerAccountSummary;
DROP VIEW IF EXISTS RecentTransactions;
DROP PROCEDURE IF EXISTS Deposit;
DROP PROCEDURE IF EXISTS Withdraw;
DROP PROCEDURE IF EXISTS Transfer;

-- Table 1: Users (New for demo: Bank staff authentication)
-- Stores login credentials for system users (e.g., admins, tellers).
CREATE TABLE Users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,  -- Store hashed passwords (e.g., via SHA-256 or bcrypt)
    role VARCHAR(20) NOT NULL CHECK (role IN ('admin', 'teller', 'viewer')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table 2: Customers
-- Stores customer personal information.
CREATE TABLE Customers (
    customer_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(20),
    address TEXT,
    date_of_birth DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Table 3: Accounts
-- Stores bank account details linked to customers.
-- Each customer can have multiple accounts.
CREATE TABLE Accounts (
    account_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    account_number VARCHAR(20) UNIQUE NOT NULL,
    account_type VARCHAR(20) NOT NULL CHECK (account_type IN ('savings', 'checking', 'credit', 'investment')),
    balance DECIMAL(15, 2) DEFAULT 0.00 CHECK (balance >= 0),
    interest_rate DECIMAL(5, 4) DEFAULT 0.0000,  -- e.g., 0.0150 for 1.5%
    opened_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(10) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'closed')),
    FOREIGN KEY (customer_id) REFERENCES Customers(customer_id) ON DELETE CASCADE,
    INDEX idx_accounts_customer_id (customer_id),
    INDEX idx_accounts_number (account_number),
    INDEX idx_accounts_status (status)
);

-- Table 4: Transactions
-- Stores transaction history for accounts.
-- Supports deposits, withdrawals, and transfers (transfers link to a 'from_account' if applicable).
CREATE TABLE Transactions (
    transaction_id INT AUTO_INCREMENT PRIMARY KEY,
    from_account_id INT,  -- NULL for deposits; used for withdrawals/transfers
    to_account_id INT,    -- NULL for withdrawals; used for deposits/transfers
    account_id INT NOT NULL,  -- The primary account affected (for deposits/withdrawals)
    transaction_type VARCHAR(20) NOT NULL CHECK (transaction_type IN ('deposit', 'withdrawal', 'transfer')),
    amount DECIMAL(15, 2) NOT NULL CHECK (amount > 0),
    fee DECIMAL(15, 2) DEFAULT 0.00 CHECK (fee >= 0),
    transaction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    description VARCHAR(255),
    created_by INT,  -- References Users.user_id for audit trail
    FOREIGN KEY (from_account_id) REFERENCES Accounts(account_id) ON DELETE SET NULL,
    FOREIGN KEY (to_account_id) REFERENCES Accounts(account_id) ON DELETE SET NULL,
    FOREIGN KEY (account_id) REFERENCES Accounts(account_id) ON DELETE CASCADE,
    FOREIGN KEY (created_by) REFERENCES Users(user_id) ON DELETE SET NULL,
    INDEX idx_transactions_account_id (account_id),
    INDEX idx_transactions_from_id (from_account_id),
    INDEX idx_transactions_to_id (to_account_id),
    INDEX idx_transactions_date (transaction_date),
    INDEX idx_transactions_type (transaction_type)
);

-- Trigger 1: Update balance on deposit (after insert)
DELIMITER //
CREATE TRIGGER after_deposit_update_balance
AFTER INSERT ON Transactions
FOR EACH ROW
BEGIN
    IF NEW.transaction_type = 'deposit' THEN
        UPDATE Accounts 
        SET balance = balance + (NEW.amount - NEW.fee)
        WHERE account_id = NEW.to_account_id OR account_id = NEW.account_id;
    END IF;
END//
DELIMITER ;

-- Trigger 2: Update balance on withdrawal (after insert)
DELIMITER //
CREATE TRIGGER after_withdrawal_update_balance
AFTER INSERT ON Transactions
FOR EACH ROW
BEGIN
    IF NEW.transaction_type = 'withdrawal' THEN
        UPDATE Accounts 
        SET balance = balance - (NEW.amount + NEW.fee)
        WHERE account_id = NEW.from_account_id OR account_id = NEW.account_id;
    END IF;
END//
DELIMITER ;

-- Trigger 3: Handle transfer (debit from, credit to) - after insert
DELIMITER //
CREATE TRIGGER after_transfer_update_balances
AFTER INSERT ON Transactions
FOR EACH ROW
BEGIN
    IF NEW.transaction_type = 'transfer' THEN
        -- Debit from account
        UPDATE Accounts 
        SET balance = balance - (NEW.amount + NEW.fee)
        WHERE account_id = NEW.from_account_id;
        
        -- Credit to account (no fee on receiving end for simplicity)
        UPDATE Accounts 
        SET balance = balance + NEW.amount
        WHERE account_id = NEW.to_account_id;
    END IF;
END//
DELIMITER ;

-- View 1: Customer Account Summary (for demo reporting)
CREATE VIEW CustomerAccountSummary AS
SELECT 
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    c.email,
    a.account_id,
    a.account_number,
    a.account_type,
    a.balance,
    a.status,
    COUNT(t.transaction_id) AS total_transactions
FROM Customers c
JOIN Accounts a ON c.customer_id = a.customer_id
LEFT JOIN Transactions t ON a.account_id = t.account_id
GROUP BY c.customer_id, a.account_id
ORDER BY c.last_name, a.account_number;

-- View 2: Recent Transactions (last 30 days, for demo dashboard)
CREATE VIEW RecentTransactions AS
SELECT 
    t.transaction_id,
    a.account_number,
    t.transaction_type,
    t.amount,
    t.fee,
    t.amount + t.fee AS total_amount,
    t.transaction_date,
    t.description,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name
FROM Transactions t
JOIN Accounts a ON t.account_id = a.account_id
JOIN Customers c ON a.customer_id = c.customer_id
WHERE t.transaction_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
ORDER BY t.transaction_date DESC;

-- Stored Procedure 1: Deposit (safe insert with balance check)
DELIMITER //
CREATE PROCEDURE Deposit(
    IN p_account_id INT,
    IN p_amount DECIMAL(15, 2),
    IN p_fee DECIMAL(15, 2),
    IN p_description VARCHAR(255),
    IN p_created_by INT
)
BEGIN
    DECLARE current_balance DECIMAL(15, 2);
    
    -- Check if account exists and is active
    SELECT balance INTO current_balance FROM Accounts WHERE account_id = p_account_id AND status = 'active';
    
    IF current_balance IS NOT NULL AND p_amount > 0 THEN
        INSERT INTO Transactions (account_id, transaction_type, amount, fee, description, created_by, to_account_id)
        VALUES (p_account_id, 'deposit', p_amount, p_fee, p_description, p_created_by, p_account_id);
        
        SELECT 'Deposit successful' AS message, ROW_COUNT() AS affected_rows;
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid account or amount';
    END IF;
END//
DELIMITER ;

-- Stored Procedure 2: Withdraw (with overdraft check for non-credit accounts)
DELIMITER //
CREATE PROCEDURE Withdraw(
    IN p_account_id INT,
    IN p_amount DECIMAL(15, 2),
    IN p_fee DECIMAL(15, 2),
    IN p_description VARCHAR(255),
    IN p_created_by INT
)
BEGIN
    DECLARE current_balance DECIMAL(15, 2);
    DECLARE account_type_val VARCHAR(20);
    DECLARE total_withdraw DECIMAL(15, 2);
    
    SELECT balance, account_type INTO current_balance, account_type_val 
    FROM Accounts WHERE account_id = p_account_id AND status = 'active';
    
    SET total_withdraw = p_amount + p_fee;
    
    IF current_balance IS NOT NULL AND total_withdraw > 0 THEN
        IF account_type_val = 'credit' OR (current_balance >= total_withdraw) THEN
            INSERT INTO Transactions (account_id, transaction_type, amount, fee, description, created_by, from_account_id)
            VALUES (p_account_id, 'withdrawal', p_amount, p_fee, p_description, p_created_by, p_account_id);
            
            SELECT 'Withdrawal successful' AS message, ROW_COUNT() AS affected_rows;
        ELSE
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient funds';
        END IF;
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid account or amount';
    END IF;
END//
DELIMITER ;

-- Stored Procedure 3: Transfer (between accounts, with checks)
DELIMITER //
CREATE PROCEDURE Transfer(
    IN p_from_account_id INT,
    IN p_to_account_id INT,
    IN p_amount DECIMAL(15, 2),
    IN p_fee DECIMAL(15, 2),
    IN p_description VARCHAR(255),
    IN p_created_by INT
)
BEGIN
    DECLARE from_balance DECIMAL(15, 2);
    DECLARE from_type VARCHAR(20);
    DECLARE to_status VARCHAR(10);
    
    -- Validate both accounts
    SELECT balance, account_type INTO from_balance, from_type 
    FROM Accounts WHERE account_id = p_from_account_id AND status = 'active';
    
    SELECT status INTO to_status 
    FROM Accounts WHERE account_id = p_to_account_id AND status = 'active';
    
    IF from_balance IS NOT NULL AND to_status = 'active' AND p_amount > 0 THEN
        IF from_type = 'credit' OR (from_balance >= (p_amount + p_fee)) THEN
            INSERT INTO Transactions (from_account_id, to_account_id, account_id, transaction_type, amount, fee, description, created_by)
            VALUES (p_from_account_id, p_to_account_id, p_from_account_id, 'transfer', p_amount, p_fee, p_description, p_created_by);
            
            SELECT 'Transfer successful' AS message, ROW_COUNT() AS affected_rows;
        ELSE
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient funds in source account';
        END IF;
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid accounts';
    END IF;
END//
DELIMITER ;

-- Sample Data Population (for demo)
-- Insert sample users
INSERT INTO Users (username, password_hash, role) VALUES 
('admin', 'hashed_password_admin', 'admin'),
('teller1', 'hashed_password_teller', 'teller');

-- Insert sample customers
INSERT INTO Customers (first_name, last_name, email, phone, address, date_of_birth) VALUES 
('John', 'Doe', 'john.doe@example.com', '555-0101', '123 Main St, Anytown', '1980-05-15'),
('Jane', 'Smith', 'jane.smith@example.com', '555-0102', '456 Oak Ave, Anytown', '1990-08-20'),
('Bob', 'Johnson', 'bob.johnson@example.com', '555-0103', '789 Pine Rd, Anytown', '1975-12-10');

-- Insert sample accounts (linked to customers)
INSERT INTO Accounts (customer_id, account_number, account_type, balance, interest_rate) VALUES 
(1, 'ACC001', 'checking', 1500.00, 0.0000),
(1, 'ACC002', 'savings', 5000.00, 0.0150),
(2, 'ACC003', 'checking', 2500.00, 0.0000),
(2, 'ACC004', 'credit', 0.00, 0.0000),  -- Credit starts at 0 (limit handled separately in real system)
(3, 'ACC005', 'savings', 3000.00, 0.0200);

-- Insert sample transactions (triggers will update balances automatically)
-- Note: For transfers in sample, we're using direct inserts; in practice, use procedures.
INSERT INTO Transactions (account_id, transaction_type, amount, fee, description, created_by, to_account_id) VALUES 
(1, 'deposit', 1000.00, 0.00, 'Initial deposit', 1, 1),
(1, 'withdrawal', 200.00, 1.50, 'ATM withdrawal', 2, NULL),
(3, 'deposit', 500.00, 0.00, 'Salary deposit', 2, 3),
(1, 'transfer', 1000.00, 5.00, 'Transfer to savings', 1, 2);  -- from ACC001 to ACC002

-- Demo Queries (run these to showcase)
-- SELECT * FROM CustomerAccountSummary;
-- SELECT * FROM RecentTransactions;
-- CALL Deposit(1, 500.00, 0.00, 'Demo deposit', 1);
-- CALL Withdraw(1, 100.00, 0.00, 'Demo withdrawal', 2);
-- CALL Transfer(1, 3, 200.00, 2.00, 'Demo transfer from checking to another checking', 1);

-- End of schema. For production, add more security, auditing, and backups.
```
