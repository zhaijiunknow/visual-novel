import sys
import pandas as pd

sys.stdout.reconfigure(encoding='utf-8')

df = pd.read_excel('身体动画数据.xlsx')
print(df.to_string(index=False))
