-- Account Inactivity Alert

WITH latest_transactions AS (
    -- Get the most recent transaction date for each plan
    SELECT 
        sa.plan_id,
        MAX(sa.transaction_date) AS last_transaction_date
    FROM 
        adashi_staging.savings_savingsaccount sa
    WHERE 
        sa.confirmed_amount > 0 -- Only consider inflow transactions
        AND (sa.transaction_status = 'success' or 
			sa.transaction_status = 'successful' or 
            sa.transaction_status = 'monnify_success' ) -- Only successful transactions
    GROUP BY 
        sa.plan_id
)

SELECT 
    pl.id AS plan_id,
    pl.owner_id,
    CASE 
        WHEN pl.is_regular_savings = 1 THEN 'Savings'
        WHEN pl.is_a_fund = 1 THEN 'Investment'
        ELSE 'Other'
    END AS type,
    lt.last_transaction_date,
    DATEDIFF(CURDATE(), COALESCE(lt.last_transaction_date, pl.created_on)) AS inactivity_days
FROM 
    adashi_staging.plans_plan pl
LEFT JOIN 
    latest_transactions lt ON pl.id = lt.plan_id
WHERE 
    -- Account is either a savings or investment plan
    (pl.is_regular_savings = 1 OR pl.is_a_fund = 1)
    -- Plan is active is active (not archived or deleted)
    AND pl.is_archived = 0
    AND pl.is_deleted = 0
    -- No transactions in the last 365 days or no transactions ever
    AND (
        DATEDIFF(CURDATE(), COALESCE(lt.last_transaction_date, pl.created_on)) > 365
        OR lt.last_transaction_date IS NULL
    )
ORDER BY 
    inactivity_days DESC;
