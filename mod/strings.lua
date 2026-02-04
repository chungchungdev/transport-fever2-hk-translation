local descHK = [[此Mod提供香港繁體中文翻譯和修正誤譯

使用方法:
1. 設定->基本->語言
2. 選擇「香港繁體」


更改:
- 誤譯，例如：日誌(Logs)->木材、船隻(Shipments)->出貨
- 部份用語
- 部份量度單位譯法
- 部份製造商譯法
]]

function data()
  return {
    en = {
      MOD_NAME = "Hong Kong Traditional Chinese",
      MOD_DESC = descHK
    },
    zh_HK = {
      MOD_NAME = "香港繁體中文翻譯",
      MOD_DESC = descHK
    },
    zh_TW = {
      MOD_NAME = "香港繁體中文翻譯",
      MOD_DESC = descHK
    }
  }
end
