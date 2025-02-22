function handle_POST_transactions() {
  ID=${PARAMS["id"]}
  AMOUNT=$(echo "$BODY" | jq -r '.valor')
  TRANSACTION_TYPE=$(echo "$BODY" | jq -r '.tipo')
  DESCRIPTION=$(echo "$BODY" | jq -r '.descricao')

  if [ "$TRANSACTION_TYPE" == "c" ]; then
    OPERATION="+"
  else
    OPERATION="-"
  fi

  if [ ! -z "$ID" ]; then
    QUERY="
INSERT INTO transactions (account_id, amount, description, transaction_type)
VALUES ($ID, $AMOUNT, '$DESCRIPTION', '$TRANSACTION_TYPE');

UPDATE balances
SET amount = amount $OPERATION $AMOUNT
WHERE balances.account_id = $ID;

SELECT 
  json_build_object(
    'limite', accounts.limit_amount,
    'saldo', balances.amount
  )
FROM accounts 
LEFT JOIN balances ON balances.account_id = accounts.id
WHERE account_id = $ID"

    RESULT=`psql -t -h pgbouncer -U postgres -d postgres -p 6432 -c "$QUERY" | tr -d '[:space:]'` 

    if [ ! -z "$RESULT" ]; then

      RESPONSE=$(cat views/bank_statement.jsonr | sed "s/{{data}}/$RESULT/")
    else
      RESPONSE=$(cat views/404.htmlr)
    fi
  fi
}
