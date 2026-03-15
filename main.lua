require "import"
import "android.speech.SpeechRecognizer"
import "android.speech.RecognizerIntent"
import "android.content.Intent"
import "android.content.Context"
import "android.net.Uri"
import "android.widget.*"
import "android.view.*"
import "com.androlua.LuaDialog"
import "android.os.Vibrator"
import "android.graphics.Typeface"
import "android.text.Editable"
import "android.text.TextWatcher"
import "java.lang.String"
import "cjson"

-- Solución al error de nil value: detecta si el sistema usa http o Http
local http = http or Http 
local context = service
local vibrator = context.getSystemService(Context.VIBRATOR_SERVICE)
local PREFS_NAME = "DictadooooooPrefs"
local prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

-- === CONFIGURACIÓN DE ACTUALIZACIÓN ===
local UPDATES_URL = "https://raw.githubusercontent.com/Misterplugins24/Esctips/main/transcript.txt"
local FECHA_ACTUAL = "03/10/2026" 

-- === Función de voz nativa de Jieshuo ===
local function hablar(texto)
  service.speak(texto)
end

-- === Helpers de Preferencias ===
local function saveGroqApiKey(apiKey) prefs.edit().putString("groq_api_key", apiKey).apply() end
local function loadGroqApiKey() return prefs.getString("groq_api_key", "") end
local function saveTraductorEnabled(v) prefs.edit().putBoolean("traductor_enabled", v).apply() end
local function loadTraductorEnabled() return prefs.getBoolean("traductor_enabled", false) end
local function saveEmojisEnabled(v) prefs.edit().putBoolean("emojis_enabled", v).apply() end
local function loadEmojisEnabled() return prefs.getBoolean("emojis_enabled", false) end
local function saveOfflineMode(v) prefs.edit().putBoolean("offline_mode", v).apply() end
local function loadOfflineMode() return prefs.getBoolean("offline_mode", false) end
local function saveIdiomaDestino(v) prefs.edit().putString("idioma_destino", v).apply() end
local function loadIdiomaDestino() return prefs.getString("idioma_destino", "Inglés") end
local function saveOpenMode(v) prefs.edit().putInt("open_mode", v).apply() end
local function loadOpenMode() 
  local m = prefs.getInt("open_mode", 1)
  return (m < 1 or m > 3) and 1 or m 
end

-- === LÓGICA DE ACTUALIZACIÓN CORREGIDA ===

local function descargarNuevoCodigo(url)
  http.get(url, function(code, body)
    if code == 200 and body then
      local rutaArchivo = service.getFilesDir() .. "/main.lua"
      local f = io.open(rutaArchivo, "w")
      if f then
        f:write(body)
        f:close()
        hablar("Actualización completada. Por favor, reinicia el plugin.")
      end
    else
      hablar("Error al descargar la actualización.")
    end
  end)
end

local function verificarActualizacion(callbackAlTerminar)
  if not http then 
    callbackAlTerminar() 
    return 
  end

  http.get(UPDATES_URL, function(code, body)
    if code == 200 and body then
      local lineas = {}
      for s in body:gmatch("[^\r\n]+") do table.insert(lineas, s) end
      
      if #lineas >= 1 then
        local nuevaFecha = lineas[1]
        local enlaceDescarga = lineas[#lineas]
        
        if nuevaFecha ~= FECHA_ACTUAL then
          local cambios = ""
          for i = 2, #lineas - 1 do cambios = cambios .. lineas[i] .. "\n" end
          
          local d = LuaDialog(service)
          d.setTitle("Actualización Disponible")
          d.setMessage("Nueva fecha: " .. nuevaFecha .. "\n\nCambios:\n" .. cambios)
          d.setPositiveButton("Actualizar ahora", {onClick=function()
            descargarNuevoCodigo(enlaceDescarga)
          end})
          d.setNegativeButton("Luego", {onClick=function()
            callbackAlTerminar()
          end})
          d.show()
        else
          callbackAlTerminar()
        end
      else
        callbackAlTerminar()
      end
    else
      callbackAlTerminar()
    end
  end)
end

-- === Lista de Idiomas ===
local todosLosIdiomas = {
  "Afrikáans", "Albanés", "Alemán", "Amhárico", "Árabe", "Armenio", "Azerbaiyano",
  "Bengali", "Bielorruso", "Birmano", "Bosnio", "Búlgaro", "Catalán", "Checo", 
  "Chino (Simplificado)", "Chino (Tradicional)", "Coreano", "Croata", "Danés", 
  "Eslovaco", "Esloveno", "Español", "Esperanto", "Estonio", "Euskera", "Filipino", 
  "Finlandés", "Francés", "Galés", "Gallego", "Georgiano", "Griego", "Gujarati",
  "Hausa", "Hebreo", "Hindi", "Húngaro", "Indonesio", "Inglés", "Irlandés", 
  "Italiano", "Japonés", "Javanés", "Jémer", "Kazajo", "Kirguís", "Laosiano", 
  "Latín", "Letón", "Lituano", "Macedonio", "Malabar", "Malayo", "Malgache", 
  "Maltés", "Maorí", "Maratí", "Mongol", "Náhuatl", "Neerlandés", "Nepalí", 
  "Noruego", "Panyabí", "Persa", "Polaco", "Portugués", "Quechua", "Rumano", 
  "Ruso", "Serbio", "Sindhi", "Suajili", "Sueco", "Sundanés", "Tagalo", 
  "Tailandés", "Tamil", "Tártaro", "Telugu", "Tibetano", "Turco", "Ucraniano", 
  "Urdu", "Uzbeko", "Vietnamita", "Xhosa", "Yidis", "Yoruba", "Zulú"
}

-- === DIÁLOGOS Y AJUSTES ===

local function showFirstTimeApiDialog()
  local d = LuaDialog(service)
  d.setTitle("Dictado Evolutivo")
  local layout = LinearLayout(service)
  layout.setOrientation(LinearLayout.VERTICAL)
  layout.setPadding(40,40,40,40)
  
  local tvMsg = TextView(service)
  tvMsg.setText("Bienvenido a dictado evolutivo.\nPor favor introduce tu clave Api de Groq.")
  layout.addView(tvMsg)
  
  local ed = EditText(service)
  ed.setHint("Pega aquí tu clave API...")
  layout.addView(ed)

  local btnGetLink = Button(service)
  btnGetLink.setText("Obtener mi clave Api de Groq")
  btnGetLink.setOnClickListener{onClick=function()
    local url = "https://console.groq.com/keys"
    local intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
    intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    service.startActivity(intent)
  end}
  layout.addView(btnGetLink)
  
  d.setView(layout)
  d.setPositiveButton("Configurar", {onClick=function()
    local key = ed.getText().toString()
    if key ~= "" then
      saveGroqApiKey(key)
      hablar("Clave guardada.")
    end
  end})
  d.show()
end

local function showLanguageSelector(btnRef)
  local langDialog = LuaDialog(service)
  langDialog.setTitle("Elegir idioma")
  local layout = LinearLayout(service)
  layout.setOrientation(LinearLayout.VERTICAL)
  layout.setPadding(40,40,40,40)
  local searchEdit = EditText(service)
  searchEdit.setHint("Buscar idioma...")
  layout.addView(searchEdit)
  local adapter = ArrayAdapter(service, android.R.layout.simple_list_item_1, String(todosLosIdiomas))
  local listView = ListView(service)
  listView.setAdapter(adapter)
  layout.addView(listView)
  searchEdit.addTextChangedListener(TextWatcher{
    onTextChanged=function(s) adapter.getFilter().filter(tostring(s)) end
  })
  listView.setOnItemClickListener(AdapterView.OnItemClickListener{
    onItemClick=function(parent, view)
      local sel = tostring(view.getText())
      saveIdiomaDestino(sel)
      btnRef.setText("Elegir idioma Traducir: " .. sel)
      langDialog.dismiss()
    end
  })
  langDialog.setView(layout).show()
end

local function showSettings()
  local dialog = LuaDialog(service)
  dialog.setTitle("Ajustes del Dictado")
  local scroll = ScrollView(service)
  local layout = LinearLayout(service)
  layout.setOrientation(LinearLayout.VERTICAL)
  layout.setPadding(40,40,40,40)

  local swTrad = Switch(service).setText("Traductor")
  swTrad.setChecked(loadTraductorEnabled())
  swTrad.setOnCheckedChangeListener{onCheckedChanged=function(_, c) saveTraductorEnabled(c) end}
  layout.addView(swTrad)

  local btnIdioma = Button(service).setText("Elegir idioma Traducir: " .. loadIdiomaDestino())
  btnIdioma.setOnClickListener{onClick=function() showLanguageSelector(btnIdioma) end}
  layout.addView(btnIdioma)

  local swEmoji = Switch(service).setText("Activar emoticones")
  swEmoji.setChecked(loadEmojisEnabled())
  swEmoji.setOnCheckedChangeListener{onCheckedChanged=function(_, c) saveEmojisEnabled(c) end}
  layout.addView(swEmoji)

  local swOffline = Switch(service).setText("Modo sin conexión")
  swOffline.setChecked(loadOfflineMode())
  swOffline.setOnCheckedChangeListener{onCheckedChanged=function(_, c) saveOfflineMode(c) end}
  layout.addView(swOffline)

  local btnApi = Button(service).setText("Gestionar API Key")
  btnApi.setOnClickListener{onClick=function()
    local d = LuaDialog(service).setTitle("API Key")
    local ed = EditText(service).setText(loadGroqApiKey())
    d.setView(ed).setPositiveButton("Guardar", {onClick=function() saveGroqApiKey(ed.getText().toString()) end}).show()
  end}
  layout.addView(btnApi)

  local btnClose = Button(service).setText("Cerrar Ajustes")
  btnClose.setOnClickListener{onClick=function() dialog.dismiss() end}
  layout.addView(btnClose)

  scroll.addView(layout)
  dialog.setView(scroll).show()
end

-- === Lógica del Dictado ===
local function iniciarDictado()
  local nodo = service.getEditText()
  local apiKey = loadGroqApiKey()

  if apiKey == "" and not loadOfflineMode() then
    showFirstTimeApiDialog()
    return
  end
  
  if not nodo then
    showSettings()
    return
  end

  vibrator.vibrate(100)
  local recognizer = SpeechRecognizer.createSpeechRecognizer(service)
  local intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
  intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, "es-ES")

  local listener = {
    onResults=function(results)
      local data = results.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
      if data and not data.isEmpty() then
        local texto = luajava.astable(data)[1]
        if texto:lower():find("ajustes") then showSettings() return end

        if loadOfflineMode() then
          service.insertText(nodo, texto .. "\n")
        else
          local promptSystem = "ERES UN ASISTENTE DE TEXTO ESTRICTO. "
          if loadTraductorEnabled() then
            promptSystem = promptSystem .. "TRADUCE al idioma " .. loadIdiomaDestino() .. "."
          else
            promptSystem = promptSystem .. "PUNTÚA el texto en español sin cambiar palabras."
          end
          if loadEmojisEnabled() then
            promptSystem = promptSystem .. " Inserta emojis pertinentes de forma natural."
          end

          http.post("https://api.groq.com/openai/v1/chat/completions", 
            cjson.encode({
              messages = {{role="system", content=promptSystem}, {role="user", content=texto}},
              model = "llama-3.3-70b-versatile",
              temperature = 0
            }), 
            {["Authorization"]="Bearer "..apiKey, ["Content-Type"]="application/json"},
            function(code, content)
              if code == 200 then
                local res = cjson.decode(content)
                service.insertText(nodo, res.choices[1].message.content .. "\n")
              else
                service.insertText(nodo, texto .. "\n")
              end
            end)
        end
      end
    end,
    onError=function() hablar("Error de voz") end
  }
  recognizer.setRecognitionListener(listener)
  recognizer.startListening(intent)
end

-- === INICIO DEL PLUGIN ===
verificarActualizacion(function()
  iniciarDictado()
end)
