
-- High-Value Customers with Multiple Products

SELECT 
    cu.id as owner_id,
    CONCAT(cu.first_name, ' ', cu.last_name) as name,
    COUNT(DISTINCT CASE WHEN pl.is_regular_savings = 1 THEN pl.id END) AS savings_count,
    COUNT(DISTINCT CASE WHEN pl.is_a_fund = 1 THEN pl.id END) AS investment_count,
    ROUND(SUM(sa.confirmed_amount)/100, 2) AS total_deposits
FROM 
    adashi_staging.users_customuser cu
INNER JOIN 
    adashi_staging.plans_plan pl ON cu.id = pl.owner_id
INNER JOIN 
    adashi_staging.savings_savingsaccount sa ON pl.id = sa.plan_id
WHERE 
	-- Only count successful transactions
	sa.transaction_status = 'success' or       
	sa.transaction_status = 'successful' or  
	sa.transaction_status = 'monnify_success' 
GROUP BY 
    cu.id, cu.name
HAVING 
    SUM(CASE WHEN pl.is_regular_savings = 1 AND sa.confirmed_amount > 0 THEN 1 ELSE 0 END) >= 1
    AND 
    SUM(CASE WHEN pl.is_a_fund = 1 AND sa.confirmed_amount > 0 THEN 1 ELSE 0 END) >= 1
ORDER BY 
    total_deposits DESC;
