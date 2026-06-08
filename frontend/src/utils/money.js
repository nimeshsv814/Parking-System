export const DEFAULT_BOOKING_AMOUNT = 50;

export const getAffordableAmount = (amount) => {
  const numericAmount = Number(amount);
  return Number.isFinite(numericAmount) && numericAmount > 0 ? numericAmount : DEFAULT_BOOKING_AMOUNT;
};

export const formatRupees = (amount) => `Rs ${getAffordableAmount(amount).toFixed(2)}`;
