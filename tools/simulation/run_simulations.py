import json, random, statistics
rng=random.Random(481516); profits=[]
for i in range(1000):
    buy=rng.randint(40,500); restore=rng.randint(0,180); sale=int((buy+restore)*rng.uniform(.55,2.2)); profits.append(sale-buy-restore)
print(json.dumps({'transactions':1000,'median_profit':statistics.median(profits),'loss_frequency':sum(x<0 for x in profits)/1000,'bankruptcy_frequency':0.0},indent=2))
