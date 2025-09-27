
-- PL/SQL stored procedures for the Financial Transaction Tracking System.
-- This script is designed for Oracle Database (PL/SQL syntax).
-- Assumptions:
-- - The schema (tables: Customers, Accounts, Transactions, Users) is already created as per the previous MySQL-compatible schema.
--   For Oracle, you may need to adjust auto-increment (e.g., use SEQUENCE and TRIGGER for primary keys instead of AUTO_INCREMENT).
--   Example: For customer_id, create a sequence CUSTOMERS_SEQ and trigger to populate it.
-- - Monetary values use NUMBER(15,2) equivalent to DECIMAL(15,2).
-- - Transaction_date uses SYSDATE for current timestamp.
-- - Error handling: Uses EXCEPTION blocks to catch and raise meaningful errors.
-- - For demo/production: Add more validation (e.g., check account status, sufficient balance) as needed.
-- - To execute: Run this in Oracle SQL Developer, SQL*Plus, or similar tool after schema setup.

-- Example Oracle Adjustments for Auto-Increment (if not already set up):
-- CREATE SEQUENCE customers_seq START WITH 1 INCREMENT BY 1;
-- CREATE OR REPLACE TRIGGER customers_trg
-- BEFORE INSERT ON Customers
-- FOR EACH ROW
-- BEGIN
--   :NEW.customer_id := customers_seq.NEXTVAL;
-- END;
-- /
-- Similar for other tables (Accounts, Transactions, Users).

-- Procedure 1: Insert New Transaction
-- Inserts a new record into the Transactions table.
-- Validates: Account exists and is active, amount > 0, valid transaction_type.
-- Does NOT update balances here (use triggers as in the schema, or add logic if needed).
-- Parameters:
-- - p_from_account_id: Source account (NULL for deposits).
-- - p_to_account_id: Destination account (NULL for withdrawals).
-- - p_account_id: Primary account affected.
-- - p_transaction_type: 'deposit', 'withdrawal', or 'transfer'.
-- - p_amount: Transaction amount (>0).
-- - p_fee: Optional fee (>=0).
-- - p_description: Optional description.
-- - p_created_by: User ID from Users table.
-- Returns: Success message or raises exception on error.
CREATE OR REPLACE PROCEDURE InsertNewTransaction(
    p_from_account_id IN Transactions.from_account_id%TYPE,
    p_to_account_id IN Transactions.to_account_id%TYPE,
    p_account_id IN Transactions.account_id%TYPE,
    p_transaction_type IN Transactions.transaction_type%TYPE,
    p_amount IN Transactions.amount%TYPE,
    p_fee IN Transactions.fee%TYPE DEFAULT 0,
    p_description IN Transactions.description%TYPE DEFAULT NULL,
    p_created_by IN Transactions.created_by%TYPE
) AS
    v_account_status VARCHAR2(10);
    v_invalid_type EXCEPTION;
    v_invalid_amount EXCEPTION;
    v_account_not_found EXCEPTION;
BEGIN
    -- Validate transaction_type
    IF p_transaction_type NOT IN ('deposit', 'withdrawal', 'transfer') THEN
        RAISE v_invalid_type;
    END IF;
    
    -- Validate amount > 0
    IF p_amount <= 0 THEN
        RAISE v_invalid_amount;
    END IF;
    
    -- Validate primary account exists and is active
    SELECT status INTO v_account_status
    FROM Accounts
    WHERE account_id = p_account_id;
    
    IF v_account_status != 'active' THEN
        RAISE v_account_not_found;
    END IF;
    
    -- For transfers, validate from and to accounts (if provided)
    IF p_transaction_type = 'transfer' THEN
        IF p_from_account_id IS NULL OR p_to_account_id IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'Transfer requires both from and to account IDs.');
        END IF;
        
        -- Check from account (simplified; add balance check if needed)
        SELECT status INTO v_account_status
        FROM Accounts
        WHERE account_id = p_from_account_id;
        IF v_account_status != 'active' THEN
            RAISE v_account_not_found;
        END IF;
        
        -- Check to account
        SELECT status INTO v_account_status
        FROM Accounts
        WHERE account_id = p_to_account_id;
        IF v_account_status != 'active' THEN
            RAISE v_account_not_found;
        END IF;
    END IF;
    
    -- Insert the transaction (transaction_id auto-generated via sequence/trigger)
    INSERT INTO Transactions (
        from_account_id,
        to_account_id,
        account_id,
        transaction_type,
        amount,
        fee,
        transaction_date,
        description,
        created_by
    ) VALUES (
        p_from_account_id,
        p_to_account_id,
        p_account_id,
        p_transaction_type,
        p_amount,
        p_fee,
        SYSDATE,
        p_description,
        p_created_by
    );
    
    -- Commit the insert
    COMMIT;
    
    -- Success message (can be queried or used in app)
    DBMS_OUTPUT.PUT_LINE('Transaction inserted successfully. Transaction ID: ' || SQL%ROWCOUNT);
    
EXCEPTION
    WHEN v_invalid_type THEN
        RAISE_APPLICATION_ERROR(-20002, 'Invalid transaction type. Must be ''deposit'', ''withdrawal'', or ''transfer''.');
    WHEN v_invalid_amount THEN
        RAISE_APPLICATION_ERROR(-20003, 'Amount must be greater than 0.');
    WHEN v_account_not_found THEN
        RAISE_APPLICATION_ERROR(-20004, 'Account not found or inactive.');
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20005, 'Specified account does not exist.');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20099, 'Error inserting transaction: ' || SQLERRM);
END InsertNewTransaction;
/

-- Procedure 2: Update Customer Phone Number
-- Updates the phone number for a specific customer.
-- Validates: Customer exists.
-- Parameters:
-- - p_customer_id: ID of the customer to update.
-- - p_new_phone: New phone number.
-- Returns: Success message or raises exception on error.
CREATE OR REPLACE PROCEDURE UpdateCustomerPhone(
    p_customer_id IN Customers.customer_id%TYPE,
    p_new_phone IN Customers.phone%TYPE
) AS
    v_customer_count NUMBER;
    v_update_count NUMBER;
BEGIN
    -- Check if customer exists
    SELECT COUNT(*) INTO v_customer_count
    FROM Customers
    WHERE customer_id = p_customer_id;
    
    IF v_customer_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20006, 'Customer not found.');
    END IF;
    
    -- Update the phone number
    UPDATE Customers
    SET phone = p_new_phone,
        updated_at = SYSDATE  -- Assuming updated_at column exists
    WHERE customer_id = p_customer_id;
    
    v_update_count := SQL%ROWCOUNT;
    
    -- Commit the update
    COMMIT;
    
    -- Success message
    DBMS_OUTPUT.PUT_LINE('Customer phone updated successfully. Rows affected: ' || v_update_count);
    
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20006, 'Customer not found.');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20099, 'Error updating customer phone: ' || SQLERRM);
END UpdateCustomerPhone;
/

-- Example Usage and Demo (Run these after creating procedures)
-- Note: Enable DBMS_OUTPUT in your tool (e.g., SET SERVEROUTPUT ON in SQL*Plus).

-- Demo 1: Insert New Transaction (e.g., a deposit)
BEGIN
    InsertNewTransaction(
        p_from_account_id => NULL,
        p_to_account_id => 1,  -- Assuming account_id 1 exists
        p_account_id => 1,
        p_transaction_type => 'deposit',
        p_amount => 250.00,
        p_fee => 0.00,
        p_description => 'Demo deposit via procedure',
        p_created_by => 1  -- Assuming user_id 1 exists
    );
END;
/

-- Verify: SELECT * FROM Transactions WHERE description = 'Demo deposit via procedure';

-- Demo 2: Update Customer Phone (e.g., for customer_id 1)
BEGIN
    UpdateCustomerPhone(
        p_customer_id => 1,
        p_new_phone => '555-9999'
    );
END;
/

-- Verify: SELECT customer_id, phone, updated_at FROM Customers WHERE customer_id = 1;

-- End of script. For production, add logging, more validations, and audit trails.
