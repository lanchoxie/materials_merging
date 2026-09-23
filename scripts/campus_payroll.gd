extends RefCounted
## Accrual and settlement only. The state facade owns and debits the wallet.
var clock: float=0.0
var accrued: float=0.0
var arrears: float=0.0
var total_paid: float=0.0

func daily_cost(people: Array, roles: Dictionary) -> float:
	var cost=0.0
	for person in people: cost+=float(roles.get(person.role,{}).get("daily_pay",0))
	return cost

func tick(delta: float, people: Array, config: Dictionary, wallet: float) -> Dictionary:
	var result={"paid":0.0,"settled":false,"arrears":arrears}
	if not is_finite(delta) or delta<=0: return result
	var period=maxf(1,float(config.payroll.period_seconds))
	accrued+=daily_cost(people,config.roles)*delta/maxf(1,float(config.day_seconds))
	clock+=delta
	if clock+0.00001<period: return result
	clock=fmod(clock,period)
	arrears+=accrued; accrued=0
	result.paid=pay_arrears(wallet)
	result.settled=true; result.arrears=arrears
	return result

func pay_arrears(wallet: float) -> float:
	var paid=minf(maxf(0,wallet),arrears)
	arrears=maxf(0,arrears-paid)
	if arrears<0.000001: arrears=0
	total_paid+=paid
	return paid

func work_factor(config: Dictionary) -> float:
	return float(config.payroll.arrears_work_factor) if arrears>0 else 1.0

func serialize() -> Dictionary:
	return {"clock":clock,"accrued":accrued,"arrears":arrears,"total_paid":total_paid}

func restore(data: Dictionary) -> bool:
	for field in ["clock","accrued","arrears","total_paid"]:
		var value=data.get(field)
		if not (value is int or value is float) or not is_finite(float(value)) or float(value)<0 or float(value)>1e12: return false
	clock=float(data.clock); accrued=float(data.accrued); arrears=float(data.arrears); total_paid=float(data.total_paid)
	return true
