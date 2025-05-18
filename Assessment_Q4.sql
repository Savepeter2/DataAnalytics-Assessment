-- Customer Lifetime Value (CLV) Estimation

WITH customer_transactions AS (
    -- Calculate transaction metrics for each customer
    SELECT 
        cu.id AS customer_id,
        CONCAT(cu.first_name, ' ', cu.last_name) as name,
        -- Calculate tenure in months from signup to present
        TIMESTAMPDIFF(MONTH, cu.date_joined, CURDATE()) AS tenure_months,
        -- Count total number of transactions
        COUNT(sa.id) AS total_transactions,
        -- Calculate total profit (0.1% of transaction value)
        SUM(sa.confirmed_amount/100 * 0.001) AS total_profit
    FROM 
        adashi_staging.users_customuser cu
    JOIN 
     adashi_staging.savings_savingsaccount sa 
     ON cu.id = sa.owner_id
    WHERE 
        sa.transaction_status = 'success'
        AND sa.confirmed_amount > 0
    GROUP BY 
        cu.id, cu.name, cu.date_joined
    -- Ensure we have some meaningful tenure to avoid division by zero
    HAVING 
        TIMESTAMPDIFF(MONTH, cu.date_joined, CURDATE()) >= 1
)

SELECT 
    customer_id,
    name,
    tenure_months,
    total_transactions,
    -- CLV formula: (total_transactions / tenure_months) * 12 * avg_profit_per_transaction
    ROUND(
        (total_transactions / tenure_months) * 12 * (total_profit / total_transactions), 
        2
    ) AS estimated_clv
FROM 
    customer_transactions
ORDER BY 
    estimated_clv DESC;