// Turning database errors into something a cashier or a reseller can act on.
//
// The people using this are not technical, and an error they cannot act on is
// worse than no error at all: it teaches them the system is unreliable. Every
// message here says what happened and what to do about it.

export const peso = (v) => '₱' + Number(v || 0).toLocaleString('en-PH', {
  minimumFractionDigits: 2, maximumFractionDigits: 2,
});

export function explain(error) {
  const message = String(error?.message || error);

  if (message.includes('NOT_ENOUGH_STOCK')) {
    const short = message.match(/(\S+) is short (\d+)/);
    return short
      ? `Not enough stock: ${short[1]} is ${short[2]} unit(s) short. Someone may have `
        + 'just taken it — refresh and try a smaller quantity.'
      : 'Not enough stock for that quantity. Refresh to see what is available now.';
  }
  if (message.includes('ACCOUNT_BLOCKED')) {
    return 'This account cannot order at the moment. The credit page shows exactly '
         + 'what needs to be paid to lift it.';
  }
  if (message.includes('OVER_CREDIT_LIMIT')) {
    const n = message.match(/([\d.]+) outstanding plus ([\d.]+) ordered is beyond the ([\d.]+)/);
    return n
      ? `This order goes past the credit limit: ${peso(n[1])} already owed plus `
        + `${peso(n[2])} ordered is over the ${peso(n[3])} limit. Pay some down, or order less.`
      : 'This order would go past the credit limit.';
  }
  if (message.includes('ACCOUNT_NOT_READY')) {
    return 'This account is not approved yet — the application and documents are '
         + 'still with the owner.';
  }
  if (message.includes('PAYMENT_FIRST')) {
    return 'This account pays before dispatch. Record the payment against the '
         + 'invoice first, then send it.';
  }
  if (message.includes('SHORT_PAYMENT')) {
    const n = message.match(/([\d.]+) handed over for a ([\d.]+) sale/);
    return n ? `Not enough cash: ${peso(n[1])} handed over for a ${peso(n[2])} sale.`
             : 'Not enough cash handed over for this sale.';
  }
  if (message.includes('map_discipline')) {
    return 'That would put the shop price below the price resellers sell at. Raise the '
         + 'shop price, or lower the reseller price first.';
  }
  if (message.includes('allocation_is_whole')) {
    return 'The three shares have to add up to 100%.';
  }
  if (message.includes('FORBIDDEN') || error?.code === '42501') {
    return 'Your sign-in does not allow that.';
  }
  if (error?.code === '23505') {
    return 'That already exists — use a different code or number.';
  }
  if (error?.code === '23503') {
    return 'Something that record depends on is missing.';
  }
  // Messages raised deliberately by our own functions are already plain
  // language; anything else has its Postgres prefix trimmed.
  return message.replace(/^error:\s*/i, '');
}
