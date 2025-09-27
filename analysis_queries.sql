
-- Three examples of complex SQL queries for the Financial Transaction Tracking System.
-- This script is designed for MySQL 8.0+ (compatible with the schema_design.sql).
-- Assumptions:
-- - Schema (tables: Customers, Accounts, Transactions) is already created and populated with sample data.
-- - Queries are "complex" with multiple joins, aggregations, conditions, and window functions where appropriate.
-- - Example outputs are commented at the end of each query (based on sample data from schema_design.sql).
--   - Assumes sample data: 3 customers, 5 accounts, 4+ transactions (after initial inserts).
--   - Balances updated via triggers (e.g., ACC001: ~1293.50 after samples).
-- - To execute: Run this in MySQL Workbench, phpMyAdmin, or command line after schema setup.
-- - For demo: These queries can be used for reporting, analytics, or dashboards.

-- Query 1: INNER JOIN to Link Customer Data with Transaction Data
-- This query joins Customers, Accounts, and Transactions to retrieve detailed transaction history
-- for active customers, including customer name, account details, and transaction info.
-- Filters: Only active accounts and transactions from the last 90 days.
-- Complexity: Multiple INNER JOINs, string concatenation, date filtering, and sorting.
SELECT 
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    c.email,
    a.account_number,
    a.account_type,
    a.balance AS current_balance,
    t.transaction_id,
    t.transaction_type,
    t.amount,
    t.fee,
    t.amount + t.fee AS total_cost,
    t.transaction_date,
    t.description
FROM Customers c
INNER JOIN Accounts a ON c.customer_id = a.customer_id AND a.status = 'active'
INNER JOIN Transactions t ON a.account_id = t.account_id
WHERE t.transaction_date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)
ORDER BY c.last_name, t.transaction_date DESC;

-- Example Output (based on sample data; assumes 4 transactions in last 90 days):
/*
+-------------+----------------+--------------------------------+----------------+--------------+---------------+---------------+------------------+----------+-------+-----------------+---------------------+-----------------------------+
| customer_id | customer_name  | email                          | account_number | account_type | current_balance | transaction_id | transaction_type | amount   | fee   | total_cost      | transaction_date    | description                  |
+-------------+----------------+--------------------------------+----------------+--------------+---------------+---------------+------------------+----------+-------+-----------------+---------------------+-----------------------------+
|           1 | John Doe       | john.doe@example.com           | ACC001         | checking     |        1293.50 |             4 | transfer         |   1000.00|   5.00|         1005.00 | 2023-10-15 10:00:03 | Transfer to savings          |
|           1 | John Doe       | john.doe@example.com           | ACC001         | checking     |        1293.50 |             2 | withdrawal       |    200.00|   1.50|          201.50 | 2023-10-15 10:00:03 | ATM withdrawal               |
|           1 | John Doe       | john.doe@example.com           | ACC001         | checking     |        1293.50 |             1 | deposit          |   1000.00|   0.00|         1000.00 | 2023-10-15 10:00:03 | Initial deposit              |
|           2 | Jane Smith     | jane.smith@example.com         | ACC003         | checking     |        3000.00 |             3 | deposit          |    500.00|   0.00|          500.00 | 2023-10-15 10:00:03 | Salary deposit               |
+-------------+----------------+--------------------------------+----------------+--------------+---------------+---------------+------------------+----------+-------+-----------------+---------------------+-----------------------------+
*/

-- Query 2: GROUP BY to Find the Total Balance of Each Account
-- This query calculates the "effective total balance" for each account by summing net transaction amounts
-- (deposits - withdrawals/transfers out) and adding to the current balance from Accounts table.
-- Uses GROUP BY on account_id, with conditional aggregation (CASE for net amount).
-- Filters: Only active accounts with at least one transaction.
-- Complexity: GROUP BY with aggregation (SUM, COUNT), sub-aggregation for net, HAVING clause, and JOIN.
SELECT 
    a.account_id,
    a.account_number,
    a.account_type,
    a.customer_id,
    a.balance AS stored_balance,
    COUNT(t.transaction_id) AS total_transactions,
    SUM(
        CASE 
            WHEN t.transaction_type = 'deposit' THEN t.amount - t.fee
            WHEN t.transaction_type IN ('withdrawal', 'transfer') THEN -(t.amount + t.fee)
            ELSE 0 
        END
    ) AS net_transaction_amount,
    a.balance + COALESCE(SUM(
        CASE 
            WHEN t.transaction_type = 'deposit' THEN t.amount - t.fee
            WHEN t.transaction_type IN ('withdrawal', 'transfer') THEN -(t.amount + t.fee)
            ELSE 0 
        END
    ), 0) AS effective_total_balance
FROM Accounts a
INNER JOIN Transactions t ON a.account_id = t.account_id
WHERE a.status = 'active'
GROUP BY a.account_id, a.account_number, a.account_type, a.customer_id, a.balance
HAVING total_transactions > 0
ORDER BY effective_total_balance DESC;

-- Example Output (based on sample data; net transactions recalculate balance for verification):
/*
+-------------+----------------+--------------+-------------+---------------+------------------+-------------------------+------------------------+
| account_id  | account_number | account_type | customer_id | stored_balance | total_transactions | net_transaction_amount  | effective_total_balance |
+-------------+----------------+--------------+-------------+---------------+------------------+-------------------------+------------------------+
|           2 | ACC002         | savings      |           1 |        6000.00 |                1 |                    1000 |                 7000.00 |
|           3 | ACC003         | checking     |           2 |        3000.00 |                1 |                     500 |                 3500.00 |
|           1 | ACC001         | checking     |           1 |        1293.50 |                3 |                     793 |                 2086.50 |
+-------------+----------------+--------------+-------------+---------------+------------------+-------------------------+------------------------+
(Accounts 4 and 5 have 0 transactions, so excluded by HAVING)
*/

-- Query 3: Query Using a Subquery
-- This query finds customers who have made high-value transactions (total amount > average transaction amount across all customers)
-- using a subquery to calculate the global average transaction amount.
-- Then, for those customers, lists their accounts with balances above the average balance of their account types.
-- Complexity: Correlated subquery for average, another subquery for type-average balance, EXISTS for filtering, and window function (AVG OVER).
SELECT 
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    c.email,
    a.account_id,
    a.account_number,
    a.account_type,
    a.balance,
    AVG(a.balance) OVER (PARTITION BY a.account_type) AS avg_balance_by_type,
    (SELECT AVG(t2.amount) FROM Transactions t2) AS global_avg_transaction  -- Subquery for global average
FROM Customers c
INNER JOIN Accounts a ON c.customer_id = a.customer_id
WHERE a.status = 'active'
  AND EXISTS (
      -- Subquery: Customers with total transaction amount > global average
      SELECT 1 FROM Transactions t
      INNER JOIN Accounts a2 ON t.account_id = a2.account_id
      WHERE a2.customer_id = c.customer_id
        AND SUM(t.amount) > (SELECT AVG(amount) FROM Transactions)  -- Correlated subquery reference
      GROUP BY a2.customer_id
  )
  AND a.balance > (
      -- Subquery: Average balance per account type
      SELECT AVG(balance) FROM Accounts WHERE account_type = a.account_type AND status = 'active'
  )
ORDER BY c.customer_id, a.account_type;

-- Example Output (based on sample data; assumes John Doe (cust 1) has high total txns ~2200 > avg ~675; Jane Smith (cust 2) ~500 < avg, so only cust 1 qualifies; balances > type avg):
/*
+-------------+----------------+----------------------------+-------------+----------------+--------------+----------+----------------------+-------------------------+
| customer_id | customer_name  | email                      | account_id  | account_number | account_type | balance  | avg_balance_by_type  | global_avg_transaction  |
+-------------+----------------+----------------------------+-------------+----------------+--------------+----------+----------------------+-------------------------+
|           1 | John Doe       | john.doe@example.com       |           1 | ACC001         | checking     |   1293.50|               1751.75|                    675.00|
|           1 | John Doe       | john.doe@example.com       |           2 | ACC002         | savings      |   6000.00|               4500.00|                    675.00|
+-------------+----------------+----------------------------+-------------+----------------+--------------+----------+----------------------+-------------------------+
(Note: Only customers with high txn totals qualify; balances > their type's avg.)
*/

-- End of script. These queries demonstrate advanced SQL for analysis:
-- - JOIN: For relational reporting.
-- - GROUP BY: For aggregation and summaries.
-- - Subquery: For dynamic comparisons and filtering.
-- For production: Add indexes on join columns (e.g., customer_id, account_id) for performance.
-- Extend with parameters (e.g., via prepared statements) for dynamic dates/thresholds.
