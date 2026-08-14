/* ============================================================
   fin.usp_ReconcileSettlements
   Compares settled amounts (fin.Settlement gross) for a date
   against the EXPECTED amount derived from order payments, by
   method, and writes fin.Reconciliation rows. Variance within the
   tolerance (config 'recon.tolerance', default 0.01) -> MATCHED,
   else UNMATCHED + an ErrorLog warning.

   Marks the underlying Settlement rows RECONCILED / DISCREPANCY.
   ============================================================ */
use retaildw
;
go
CREATE OR ALTER PROCEDURE fin.usp_ReconcileSettlements
    @ReconDate DATE,
    @BatchId   UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @plog BIGINT;
exec util.usp_logstart @procname = 'fin.usp_ReconcileSettlements',
@batchid = @batchid,
@proclogid
= @plog output
;

begin try
        DECLARE @tolTxt VARCHAR(400);
exec util.usp_getconfig @paramkey = 'recon.tolerance',
@default = '0.01',
@value
= @toltxt output
;
        DECLARE @tol DECIMAL(18,4) = ISNULL(TRY_CONVERT(DECIMAL(18,4), @tolTxt), 0.01);

delete from fin.reconciliation
where recondate = @recondate
;

;
with
    expected as (
        select paymentmethod, sum(amount) as expected
        from sales.payment
        where
            cast(processedutc as date) = @recondate
            and status in ('CAPTURED', 'REFUNDED')
        group by paymentmethod
    ),
    settled as (
        select paymentmethod, sum(grossamount) as settled
        from fin.settlement
        where settlementdate = @recondate
        group by paymentmethod
    )
    insert into fin.reconciliation(
        recondate, paymentmethod, expectedamount, settledamount, variance, status
    )
select
    @recondate,
    coalesce(e.paymentmethod, s.paymentmethod),
    isnull(e.expected, 0),
    isnull(s.settled, 0),
    isnull(s.settled, 0) - isnull(e.expected, 0),
    case
        when abs(isnull(s.settled, 0) - isnull(e.expected, 0)) <= @tol
        then 'MATCHED'
        else 'UNMATCHED'
    end
from expected e
full outer join settled s on s.paymentmethod = e.paymentmethod
;

        UPDATE fin.Settlement
           SET Status = CASE WHEN r.Status = 'MATCHED' THEN 'RECONCILED' ELSE 'DISCREPANCY' END
          FROM fin.Settlement st
          JOIN fin.Reconciliation r ON r.ReconDate = st.SettlementDate AND r.PaymentMethod = st.PaymentMethod
         WHERE st.SettlementDate = @ReconDate;

        INSERT INTO util.ErrorLog (BatchId, ProcName, ErrorNumber, ErrorMessage)
        SELECT @BatchId, 'fin.usp_ReconcileSettlements', 0,
               CONCAT('Settlement mismatch ', PaymentMethod, ' var=', Variance)
          FROM fin.Reconciliation WHERE ReconDate = @ReconDate AND Status = 'UNMATCHED';

exec util.usp_logend @proclogid
= @plog
;
end try
begin catch
exec util.usp_logerror @procname = 'fin.usp_ReconcileSettlements',
@batchid
= @batchid
;
exec util.usp_logend @proclogid
= @plog,
@status
= 'FAILED'
;
throw
;
end catch
end
go
