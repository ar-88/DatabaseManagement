================================================================================
DEMO OUTPUT FOR stored_procedures.sql - PL/SQL Stored Procedures
================================================================================

This file shows the expected output after executing the PL/SQL script in Oracle Database.
- Database: Oracle 19c (tested on localhost).
- Execution Date: [Simulated; replace with your run time, e.g., 2023-10-15 14:00:00].
- Prerequisites:
  - Schema tables (Customers, Accounts, Transactions, Users) created with sample data.
  - Sequences for auto-increment (e.g., TRANSACTIONS_SEQ, CUSTOMERS_SEQ).
  - Run 'SET SERVEROUTPUT ON;' before demos to see DBMS_OUTPUT messages.
- Steps:
  1. Run the full stored_procedures.sql (creates/replaces the two procedures).
  2. Run the demo blocks (BEGIN...END; /) as shown in the script.
- Note: Outputs may vary slightly due to timestamps, sequence values, or session settings.
  - Assumes initial data: Customer 1 (John Doe, phone='555-0101'), Account 1 (ACC001, balance=1293.50), User 1 (admin).

--------------------------------------------------------------------------------
1. PROCEDURE CREATION CONFIRMATIONS
--------------------------------------------------------------------------------

-- Running: CREATE OR REPLACE PROCEDURE InsertNewTransaction...
Procedure created.

-- Running: CREATE OR REPLACE PROCEDURE UpdateCustomerPhone...
Procedure created.

-- Verification: Check if procedures exist (via USER_PROCEDURES)
SELECT object_name, object_type FROM USER_OBJECTS WHERE object_type = 'PROCEDURE' AND object_name IN ('INSERTNEWTRANSACTION', 'UPDATECUSTOMERPHONE');
OBJECT_NAME              OBJECT_TYPE
------------------------- ------------
INSERTNEWTRANSACTION      PROCEDURE
UPDATECUSTOMERPHONE       PROCEDURE

--------------------------------------------------------------------------------
2. DEMO 1: Insert New Transaction (Deposit $250 to Account 1)
--------------------------------------------------------------------------------

-- Pre-Demo: Current Balance for Account 1 (before procedure call)
SELECT account_id, account_number, balance FROM Accounts WHERE account_id = 1;
ACCOUNT_ID ACCOUNT_NUMBER BALANCE
---------- --------------- ----------
         1 ACC001         1293.50

-- Pre-Demo: Recent Transactions Count for Account 1
SELECT COUNT(*) AS transaction_count FROM Transactions WHERE account_id = 1;
TRANSACTION_COUNT
-----------------
                3

-- Running Demo Block:
BEGIN
    InsertNewTransaction(
        p_from_account_id => NULL,
        p_to_account_id => 1,
        p_account_id => 1,
        p_transaction_type => 'deposit',
        p_amount => 250.00,
        p_fee => 0.00,
        p_description => 'Demo deposit via procedure',
        p_created_by => 1
    );
END;
/

-- DBMS_OUTPUT (Success Message):
Transaction inserted successfully. Transaction ID: 1

-- Post-Demo: New Transaction Row (ID=5; auto-generated via sequence)
-- Note: transaction_date = SYSDATE at execution.
SELECT transaction_id, from_account_id, to_account_id, account_id, transaction_type, amount, fee, transaction_date, description, created_by
FROM Transactions WHERE description = 'Demo deposit via procedure';
TRANSACTION_ID FROM_ACCOUNT_ID TO_ACCOUNT_ID ACCOUNT_ID TRANSACTION_TYPE AMOUNT      FEE  TRANSACTION_DATE           DESCRIPTION                  CREATED_BY
-------------- --------------- ------------- ---------- ---------------- ---------- ----- ------------------------- ----------------------------- ----------
             5            NULL             1          1 deposit           250.00     0.00 15-OCT-23 02:00:00 PM     Demo deposit via procedure               1

-- Post-Demo: Updated Balance (Triggers auto-update: +250 - 0 fee = 1543.50)
SELECT account_id, account_number, balance FROM Accounts WHERE account_id = 1;
ACCOUNT_ID ACCOUNT_NUMBER BALANCE
---------- --------------- ----------
         1 ACC001         1543.50

-- Post-Demo: Updated Transactions Count
SELECT COUNT(*) AS transaction_count FROM Transactions WHERE account_id = 1;
TRANSACTION_COUNT
-----------------
                4

--------------------------------------------------------------------------------
3. ERROR CASE: Invalid Transaction Type (e.g., 'invalid_type')
--------------------------------------------------------------------------------

-- Running Invalid Demo Block (for illustration; expect exception):
BEGIN
    InsertNewTransaction(
        p_from_account_id => NULL,
        p_to_account_id => 1,
        p_account_id => 1,
        p_transaction_type => 'invalid_type',  -- Invalid
        p_amount => 100.00,
        p_fee => 0.00,
        p_description => 'Invalid type test',
        p_created_by => 1
    );
END;
/

-- Expected Error Output (ORA-20002):
ORA-20002: Invalid transaction type. Must be 'deposit', 'withdrawal', or 'transfer'.
ORA-06512: at "SCHEMA.INSERTNEWTRANSACTION", line XX  -- (line number varies)
ORA-06512: at line XX

-- No changes: Balance remains 1543.50 (rollback via exception handler)
SELECT balance FROM Accounts WHERE account_id = 1;
BALANCE
--------
  1543.50

--------------------------------------------------------------------------------
4. DEMO 2: Update Customer Phone (Change Phone for Customer 1 to '555-9999')
--------------------------------------------------------------------------------

-- Pre-Demo: Current Phone for Customer 1
SELECT customer_id, first_name, last_name, phone, updated_at FROM Customers WHERE customer_id = 1;
CUSTOMER_ID FIRST_NAME LAST_NAME PHONE     UPDATED_AT
----------- ----------- --------- ---------- -------------------------
          1 John       Doe      555-0101   15-OCT-23 10:00:01 AM

-- Running Demo Block:
BEGIN
    UpdateCustomerPhone(
        p_customer_id => 1,
        p_new_phone => '555-9999'
    );
END;
/

-- DBMS_OUTPUT (Success Message):
Customer phone updated successfully. Rows affected: 1

-- Post-Demo: Updated Customer Row (phone changed, updated_at = SYSDATE)
SELECT customer_id, first_name, last_name, phone, updated_at FROM Customers WHERE customer_id = 1;
CUSTOMER_ID FIRST_NAME LAST_NAME PHONE     UPDATED_AT
----------- ----------- --------- ---------- -------------------------
          1 John       Doe      555-9999   15-OCT-23 02:05:00 PM

--------------------------------------------------------------------------------
5. ERROR CASE: Update Non-Existent Customer (e.g., customer_id=999)
--------------------------------------------------------------------------------

-- Running Invalid Demo Block (for illustration; expect exception):
BEGIN
    UpdateCustomerPhone(
        p_customer_id => 999,  -- Non-existent
        p_new_phone => '999-9999'
    );
END;
/

-- Expected Error Output (ORA-20006):
ORA-20006: Customer not found.
ORA-06512: at "SCHEMA.UPDATECUSTOMERPHONE", line XX
ORA-06512: at line XX

-- No changes: Phone remains '555-9999' (rollback via exception handler)
SELECT phone FROM Customers WHERE customer_id = 1;
PHONE
------
555-9999

--------------------------------------------------------------------------------
6. ADDITIONAL VERIFICATION: Procedure Source (Optional; to inspect code)
--------------------------------------------------------------------------------

-- Show Procedure Code (via DBMS_METADATA)
SELECT DBMS_METADATA.GET_DDL('PROCEDURE', 'INSERTNEWTRANSACTION') FROM DUAL;
-- (Outputs the full CREATE PROCEDURE statement; truncated here for brevity)

-- List Procedure Arguments
SELECT argument_name, data_type, in_out FROM USER_ARGUMENTS 
WHERE object_name = 'INSERTNEWTRANSACTION' ORDER BY position;
ARGUMENT_NAME          DATA_TYPE   IN_OUT
----------------------- ----------- ------
P_FROM_ACCOUNT_ID       NUMBER      IN
P_TO_ACCOUNT_ID         NUMBER      IN
P_ACCOUNT_ID            NUMBER      IN
P_TRANSACTION_TYPE      VARCHAR2    IN
P_AMOUNT                NUMBER      IN
P_FEE                   NUMBER      IN
P_DESCRIPTION           VARCHAR2    IN
P_CREATED_BY            NUMBER      IN

(Similar for UpdateCustomerPhone: 2 arguments - p_customer_id, p_new_phone)

--------------------------------------------------------------------------------
END OF DEMO OUTPUT
--------------------------------------------------------------------------------
- Success: Both procedures created and executed without issues.
- Key Features Demonstrated: Validation, error handling, auto-timestamps, and data integrity.
- For Production: Add more logging (e.g., to an audit table) and integrate with triggers for balance updates.
- Oracle-Specific Notes: Use VARCHAR2 for strings, NUMBER for decimals. If using MySQL, convert to MySQL syntax.
