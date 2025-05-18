-- Transaction Frequency Analysis

WITH monthly_customer_transactions AS (
    -- Calculate transactions per customer per month
    SELECT 
        sa.owner_id,
        YEAR(sa.transaction_date) AS transaction_year,
        MONTH(sa.transaction_date) AS transaction_month,
        COUNT(*) AS transactions_count
    FROM 
       adashi_staging.savings_savingsaccount sa
    WHERE
		-- Include only successful transactions
        (sa.transaction_status = 'success' or       
		sa.transaction_status = 'successful' or  
		sa.transaction_status = 'monnify_success')
        AND sa.confirmed_amount > 0
    GROUP BY 
        sa.owner_id, 
        YEAR(sa.transaction_date), 
        MONTH(sa.transaction_date)
),

customer_avg_transactions AS (
    -- Calculate average transactions per month for each customer
    SELECT 
        owner_id,
        AVG(transactions_count) AS avg_transactions_per_month
    FROM 
        monthly_customer_transactions
    GROUP BY 
        owner_id
),

customer_categories AS (
    -- Categorize customers based on their average transaction frequency
    SELECT 
        CASE 
            WHEN avg_transactions_per_month >= 10 THEN 'High Frequency'
            WHEN avg_transactions_per_month >= 3 THEN 'Medium Frequency'
            ELSE 'Low Frequency'
        END AS frequency_category,
        owner_id,
        avg_transactions_per_month
    FROM 
        customer_avg_transactions
)

-- Final aggregation for output
SELECT 
    frequency_category,
    COUNT(*) AS customer_count,
    ROUND(AVG(avg_transactions_per_month), 1) AS avg_transactions_per_month
FROM 
    customer_categories
GROUP BY 
    frequency_category
ORDER BY 
    CASE 
        WHEN frequency_category = 'High Frequency' THEN 1
        WHEN frequency_category = 'Medium Frequency' THEN 2
        WHEN frequency_category = 'Low Frequency' THEN 3
    END;