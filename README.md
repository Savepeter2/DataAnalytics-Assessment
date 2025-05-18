# DataAnalytics-Assessment 


### **Question 1:**

**Objective:**
Find customers with at **least one funded savings plan** AND **one funded investment plan**, sorted by total deposits in the following format:

```
owner_id | name     | savings_count | investment_count | total_deposits
1001     | John Doe | 2             | 1                | 15000.00
```

**SQL Query:**

```sql
SELECT 
    cu.id AS owner_id,
    CONCAT(cu.first_name, ' ', cu.last_name) AS name,
    COUNT(DISTINCT CASE WHEN pl.is_regular_savings = 1 THEN pl.id END) AS savings_count,
    COUNT(DISTINCT CASE WHEN pl.is_a_fund = 1 THEN pl.id END) AS investment_count,
    ROUND(SUM(sa.confirmed_amount) / 100, 2) AS total_deposits
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
```

### **Explanation:**

The solution began by first identifying the necessary tables to retrieve the required data, which were already provided in the question.
Next, the relevant columns were identified from each table. The question specifically required customer details, with the first two columns being `owner_id` and `name`. Therefore, the query started from the `users_customuser` table, which served as a dimension table.

The question also specified customers with **at least one savings plan** and **at least one investment plan**. To achieve this, the `plans_plan` table was joined with the `users_customuser` table on the `owner_id` column to retrieve customers along with their associated plans.

Additionally, since the results needed to be sorted by **total deposits**, the `savings_savingsaccount` table was also required. This table was joined with the `plans_plan` table on the `plan_id` column to extract the deposit amounts made by each customer for both savings and investment plans.

**The required output format:**

```
owner_id | name     | savings_count | investment_count | total_deposits
1001     | John Doe | 2             | 1                | 15000.00
```

After performing the necessary joins, the required columns were selected to match the specified output format.
The `id` column from the `users_customuser` table was selected as `owner_id`.
The `first_name` and `last_name` columns were concatenated from the `users_customuser` table to produce the `name`.

The `COUNT` function was used with a `CASE` statement to get a distinct count of `plan_id`s where the `is_regular_savings` column is `1`, denoting a savings plan.
Similarly, the `COUNT` function was used to obtain a distinct count of `plan_id`s where the `is_a_fund` column is `1`, indicating an investment plan.

To calculate the **total deposits**, the `SUM` function was applied to the `confirmed_amount` column from the `savings_savingsaccount` table. The result was then divided by `100` to convert the amount from kobo to naira.
The `ROUND` function was used to round the total deposits to **2 decimal places**, as specified in the output format.

`INNER JOIN` was used for all joins to ensure that only rows with matching values in the joined tables were included, contributing to query optimization.

The `GROUP BY` clause was applied to `owner_id` and `name` in order to enable aggregation using the `COUNT` and `SUM` functions for each customer.

Conditions were added to filter rows where:

* The `is_regular_savings` column is `1` and `confirmed_amount` is greater than `0`, denoting a **savings plan with deposits**. This was achieved using the `SUM` function along with a `CASE` statement to count qualifying rows.
* The `is_a_fund` column is `1` and `confirmed_amount` is greater than `0`, denoting an **investment plan with deposits**. This was similarly implemented using the `SUM` function with a `CASE` statement.

Finally, the `ORDER BY` clause was applied to the `total_deposits` column in **descending order** to rank customers by the total amount deposited.

This approach ensured that the requirements of the question were met and the results were presented in the specified output format.

### **Challenges:**

The first challenge encountered in solving this question was a lack of awareness regarding the structure of the tables and their relationships. It was necessary to review the tables, their columns, and data types to understand how they were related and how to join them effectively to retrieve the required data, based on the provided data dictionary.

It was also observed that the `name` column in the `users_customuser` table had most of its entries as `NULL`. To address this, the `first_name` and `last_name` columns were concatenated to form the `name` column, as specified in the required output format.

Further querying was conducted on the `savings_savingsaccount` table to understand the significance of each column and determine their relevance to the question, as this table stores transaction data. It was discovered that the `transaction_status` column was particularly relevant, as it records the status of each transaction. This raised uncertainty about whether to include all transactions or only successful ones.

Upon closer inspection of the question, it became clear that the requirement was for **funded savings plans** and **funded investment plans**. Therefore, to consider a customer as having an active savings or investment plan, only successful transactions should be counted. Based on this, a condition was added to filter rows where the `transaction_status` column was either `"success"`, `"successful"`, or `"monnify_success"`, after querying all distinct values in the `transaction_status` column.

Additionally, implementing the condition to retrieve customers with at least one savings plan and at least one investment plan was initially challenging. It was important to ensure that, for a customer to be counted, there must be at least one plan where the `is_regular_savings` column is `1` and the `confirmed_amount` is greater than `0`. This verified that the customer had deposited a positive amount into a savings plan to handle the case of negative deposits in the data, and the same logic applied to investment plans.



---

### **Question 2:**

**Objective:**
Calculate the **average number of transactions per customer per month** and **categorize** each customer into one of the following frequency groups:

* **High Frequency** (≥10 transactions/month)
* **Medium Frequency** (3–9 transactions/month)
* **Low Frequency** (≤2 transactions/month)
  Return the results in the following format:

| frequency\_category | customer\_count | avg\_transactions\_per\_month |
| ------------------- | --------------- | ----------------------------- |
| High Frequency      | 250             | 15.2                          |
| Medium Frequency    | 1200            | 5.5                           |

**SQL Query:**

```sql
WITH monthly_customer_transactions AS (
    -- Calculate transactions per customer per month
    SELECT 
        sa.owner_id,
        YEAR(sa.transaction_date) AS transaction_year,
        MONTH(sa.transaction_date) AS transaction_month,
        COUNT(*) AS transactions_count
    FROM 
        adashi_staging.savings_savingsaccount sa
    -- Count successful transactions and positive deposits
    WHERE 
        (sa.transaction_status = 'success' OR       
         sa.transaction_status = 'successful' OR  
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
```


### **Explanation**

The task required calculating the average number of transactions per customer per month and categorizing them into three frequency groups:

* **High Frequency** (≥10 transactions/month)
* **Medium Frequency** (3–9 transactions/month)
* **Low Frequency** (≤2 transactions/month)

To solve this, the first step was identifying the relevant table for transaction data. The `savings_savingsaccount` table was determined to be sufficient for this task, as it contains all the necessary transaction records.

To calculate the average number of transactions per customer per month, a table was needed with four columns: `owner_id`, `transaction_year`, `transaction_month`, and `transactions_count`. With this structure, it became straightforward to calculate monthly transaction counts and then compute an average per customer.

A Common Table Expression (CTE) named `monthly_customer_transactions` was created to hold the monthly transaction counts for each customer. The `WHERE` clause filtered records by `transaction_status`, ensuring only successful transactions (`'success'`, `'successful'`, or `'monnify_success'`) were considered, and only those with a `confirmed_amount` greater than 0.

Next, a second CTE, `customer_avg_transactions`, was used to calculate the average number of transactions per month for each customer. This was achieved using the `AVG` function on the `transactions_count` column, grouped by `owner_id`.

With the average transactions per month calculated, a third CTE called `customer_categories` was created. This CTE categorized each customer based on their transaction frequency using a `CASE` statement:

* Customers with ≥10 transactions/month were labeled "High Frequency"
* Those with 3–9 transactions/month were labeled "Medium Frequency"
* Those with ≤2 transactions/month were labeled "Low Frequency"

For the final output, the following columns were required:
`frequency_category`, `customer_count`, and `avg_transactions_per_month`.

Since `customer_categories` contained `frequency_category`, `owner_id`, and `avg_transactions_per_month`, the final query used:

* `COUNT(*)` to compute the number of customers in each category
* `ROUND(AVG(...), 1)` to round the average transactions per month to one decimal place, as specified in the expected output

This structured approach made it possible to meet the requirements and produce the output exactly as defined in the question.


### **Challenges:**

Barely any challenge was encountered while solving this question. The question was broken down to its root, and each step was organized into separate CTEs. This approach made it easier to achieve the result and also improved readability and debugging.


---

### Question 3:

**Objective:**  
Find all active accounts (savings or investments) with no transactions in the last 1 year (365 days).

**Expected Output Format:**

```
plan_id | owner_id | type   | last_transaction_date | inactivity_days
1001    | 305      | Savings| 2023-08-10            | 92
```


**SQL Query:**

```sql
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
````

### **Explanation:**

The task was to find all active accounts (savings or investments) with no transactions in the last one year (365 days), presented in the specified output format.

The output format provided guidance on the necessary steps. The first column, `plan_id`, indicated that each plan ID along with its last transaction date needed to be identified. Since customers may have zero or multiple plans, obtaining these plan IDs enables retrieval of the associated `owner_id` and determination of the plan type.

A Common Table Expression (CTE) named `latest_transactions` was created to capture the most recent transaction date for each plan, filtering for rows with positive amounts and successful transaction statuses.

Following that, the `latest_transactions` CTE was joined to the `plans_plan` table on the `plan_id` column using a `LEFT JOIN`. This join was crucial to include all plans, even those without any transactions, as the focus was on active accounts with **no transactions** in the past year—therefore including plans with no transactions ever.

From the joined data, the `plan_id` and `owner_id` were selected. A `CASE` statement was applied to classify each plan’s type based on the values in the `is_regular_savings` and `is_a_fund` columns. The `last_transaction_date` was selected, and the `DATEDIFF` function calculated the number of `inactivity_days` between the current date and the last transaction date. The `COALESCE` function handled `NULL` values in the last transaction date by substituting the plan’s `created_on` date. This ensured that for plans without any transactions, inactivity was measured from the plan creation date.

The `WHERE` clause filtered the results to include only active accounts (savings or investments) that are neither archived nor deleted, based on the `is_archived` and `is_deleted` flags. Additionally, it filtered for accounts with no transactions within the last 365 days or with no transactions at all.

Finally, the results were sorted by `inactivity_days` in descending order, prioritizing accounts with the longest periods of inactivity.

This approach successfully produced the results matching the specified output format.


### **Challenges:**

Initially, the approach was to get the last transaction date for each customer by joining the `savings_savingsaccount` table with the `users_customuser` table on the `owner_id` column and then grouping by the `owner_id` column. This was based on how the question was worded.

Later, it was realized that the question was asking for the last transaction date for each plan, including the customer and plan type. This required changing the approach to get the last transaction date for each plan and then join the `savings_savingsaccount` table with the `plans_plan` table on the `plan_id` column.

Once the last transaction date for each plan was obtained, it became straightforward to get the `owner_id` and type of each plan by joining the `plans_plan` table with the `latest_transactions` CTE on the `plan_id` column.

The “active” part of the question was initially overlooked because it seemed to ask for all accounts with savings or investment plans. Therefore, an overview of the `plans_plan` and `savings_savingsaccount` tables was necessary to identify relevant columns related to this “active” condition. It was determined that “active” applies to plans, meaning plans retrieved from the `plans_plan` table should be active, i.e., where the `is_archived` and `is_deleted` columns are 0.

Lastly, in applying the main condition to find accounts with no transactions in the last 1 year (365 days), the initial approach only checked the inactivity period, ignoring cases where no transactions had ever been made. No transaction in the last 365 days means either no transaction has been made at all or the inactivity days are greater than 365.

To handle cases where the last transaction date is NULL, the `COALESCE` function was used to substitute the last transaction date with the plan’s `created_on` date. Additionally, an OR condition was added to include rows where the last transaction date is NULL.


---

### **Question 4:**


**Objective:**
For each customer, assuming the `profit_per_transaction` is **0.1% of the transaction value**, calculate:

- Account tenure (months since signup)  
- Total transactions  
- Estimated CLV  
  *(Assume: CLV = (total_transactions / tenure) * 12 * avg_profit_per_transaction)*  

Order by **estimated CLV** from highest to lowest.

```
customer_id | name     | tenure_months | total_transactions | estimated_clv
1001        | John Doe | 24            | 120                | 600.00
````

**SQL Query:**

```sql
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
````

### **Explanation:**

The task was to calculate the customer lifetime value (CLV) for each customer based on their transaction history.
After reviewing the output format, the necessary tables, and previous questions solved, a good grasp of the dataset and approach was pictured.
The process was broken down to its roots.
The question asked for the customer\_id, name, tenure\_months, and total\_transactions as the first columns in the output format.

A `customer_transactions` CTE was created to get the customer\_id, name, tenure\_months, total\_transactions, and total\_profit columns by joining the `users_customuser` table with the `savings_savingsaccount` table on the owner\_id column.
The `TIMESTAMPDIFF` function was used to calculate tenure in months from the `date_joined` column in the `users_customuser` table to the current date.
The `COUNT` function was used to count the total number of transactions for each customer, and the `SUM` function was used to calculate the total profit for each customer by multiplying the `confirmed_amount` column by the constant 'profit\_per\_transaction' of 0.1% (0.001) and dividing it by 100 to get the amount in naira.
The results were filtered to include only successful transactions with positive amounts using the WHERE clause.
Additionally, the results were filtered to ensure that the tenure is at least 1 month to avoid division by zero since the tenure\_months column is used in the CLV formula.

With the CTE containing customer\_id, name, tenure\_months, total\_transactions, and total\_profit columns, the estimated CLV for each customer was calculated using the formula provided in the question.
This brought the solution closer to the final result following the output format.
The final selection included customer\_id, name, tenure\_months, total\_transactions columns from the CTE, and the estimated\_clv column calculated using the formula.
The `ROUND` function was applied to round the estimated\_clv to 2 decimal places, as specified in the output format.
The results were then sorted by estimated\_clv in descending order using the ORDER BY clause.

This was the approach taken to solve the question and obtain the results in the specified output format.


### **Challenges:**

The major challenge faced when solving this question was initially not including the clause to filter results to ensure that the tenure is at least 1 month, which is necessary to avoid division by zero. Although there might not be any customer with a tenure of 0 months in the data, this condition is essential to ensure an accurate and reliable query and result.

Aside from that, it was an interesting question to solve, and the process of breaking it down to its roots was enjoyable.
