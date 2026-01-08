#!/usr/bin/env python3
"""
Generate comprehensive localization file for BabyInCarApp
Supports: English, Russian, Spanish, French, German, Chinese (Simplified),
Japanese, Portuguese, Arabic, Italian
"""

import json
from typing import Dict

# Translation dictionary - organized by category
TRANSLATIONS = {
    # Navigation Titles
    "nav.profile": {
        "en": "Profile",
        "ru": "Профиль",
        "es": "Perfil",
        "fr": "Profil",
        "de": "Profil",
        "zh-Hans": "个人资料",
        "ja": "プロフィール",
        "pt": "Perfil",
        "ar": "الملف الشخصي",
        "it": "Profilo"
    },
    "nav.favorites": {
        "en": "Favorites",
        "ru": "Избранное",
        "es": "Favoritos",
        "fr": "Favoris",
        "de": "Favoriten",
        "zh-Hans": "收藏",
        "ja": "お気に入り",
        "pt": "Favoritos",
        "ar": "المفضلة",
        "it": "Preferiti"
    },
    "nav.library": {
        "en": "Library",
        "ru": "Библиотека",
        "es": "Biblioteca",
        "fr": "Bibliothèque",
        "de": "Bibliothek",
        "zh-Hans": "资料库",
        "ja": "ライブラリ",
        "pt": "Biblioteca",
        "ar": "المكتبة",
        "it": "Libreria"
    },
    "nav.search": {
        "en": "Search",
        "ru": "Поиск",
        "es": "Buscar",
        "fr": "Rechercher",
        "de": "Suchen",
        "zh-Hans": "搜索",
        "ja": "検索",
        "pt": "Pesquisar",
        "ar": "بحث",
        "it": "Cerca"
    },
    "nav.insights": {
        "en": "Insights",
        "ru": "Статистика",
        "es": "Estadísticas",
        "fr": "Statistiques",
        "de": "Statistiken",
        "zh-Hans": "数据分析",
        "ja": "統計",
        "pt": "Estatísticas",
        "ar": "الإحصاءات",
        "it": "Statistiche"
    },
    "nav.assistant": {
        "en": "Ask Assistant",
        "ru": "Спросить ассистента",
        "es": "Preguntar al asistente",
        "fr": "Demander à l'assistant",
        "de": "Assistenten fragen",
        "zh-Hans": "询问助手",
        "ja": "アシスタントに聞く",
        "pt": "Perguntar ao assistente",
        "ar": "اسأل المساعد",
        "it": "Chiedi all'assistente"
    },
    "nav.downloads": {
        "en": "Manage Downloads",
        "ru": "Загрузки",
        "es": "Administrar descargas",
        "fr": "Gérer les téléchargements",
        "de": "Downloads verwalten",
        "zh-Hans": "管理下载",
        "ja": "ダウンロード管理",
        "pt": "Gerenciar downloads",
        "ar": "إدارة التنزيلات",
        "it": "Gestisci download"
    },
    "nav.settings": {
        "en": "Settings",
        "ru": "Настройки",
        "es": "Configuración",
        "fr": "Paramètres",
        "de": "Einstellungen",
        "zh-Hans": "设置",
        "ja": "設定",
        "pt": "Configurações",
        "ar": "الإعدادات",
        "it": "Impostazioni"
    },
    "nav.babyIntelligence": {
        "en": "Baby Intelligence",
        "ru": "Интеллект малыша",
        "es": "Inteligencia del bebé",
        "fr": "Intelligence du bébé",
        "de": "Baby-Intelligenz",
        "zh-Hans": "宝宝智能",
        "ja": "ベビー知能",
        "pt": "Inteligência do bebê",
        "ar": "ذكاء الطفل",
        "it": "Intelligenza del bambino"
    },
    "nav.whatWorks": {
        "en": "What Works",
        "ru": "Что работает",
        "es": "Lo que funciona",
        "fr": "Ce qui fonctionne",
        "de": "Was funktioniert",
        "zh-Hans": "有效方法",
        "ja": "効果的な方法",
        "pt": "O que funciona",
        "ar": "ما يعمل",
        "it": "Cosa funziona"
    },

    # Buttons & Actions
    "button.play": {
        "en": "Play",
        "ru": "Воспроизвести",
        "es": "Reproducir",
        "fr": "Lire",
        "de": "Abspielen",
        "zh-Hans": "播放",
        "ja": "再生",
        "pt": "Reproduzir",
        "ar": "تشغيل",
        "it": "Riproduci"
    },
    "button.pause": {
        "en": "Pause",
        "ru": "Пауза",
        "es": "Pausar",
        "fr": "Pause",
        "de": "Pause",
        "zh-Hans": "暂停",
        "ja": "一時停止",
        "pt": "Pausar",
        "ar": "إيقاف مؤقت",
        "it": "Pausa"
    },
    "button.shuffle": {
        "en": "Shuffle",
        "ru": "Случайный порядок",
        "es": "Aleatorio",
        "fr": "Aléatoire",
        "de": "Zufällig",
        "zh-Hans": "随机播放",
        "ja": "シャッフル",
        "pt": "Aleatório",
        "ar": "عشوائي",
        "it": "Casuale"
    },
    "button.save": {
        "en": "Save",
        "ru": "Сохранить",
        "es": "Guardar",
        "fr": "Enregistrer",
        "de": "Speichern",
        "zh-Hans": "保存",
        "ja": "保存",
        "pt": "Salvar",
        "ar": "حفظ",
        "it": "Salva"
    },
    "button.cancel": {
        "en": "Cancel",
        "ru": "Отмена",
        "es": "Cancelar",
        "fr": "Annuler",
        "de": "Abbrechen",
        "zh-Hans": "取消",
        "ja": "キャンセル",
        "pt": "Cancelar",
        "ar": "إلغاء",
        "it": "Annulla"
    },
    "button.done": {
        "en": "Done",
        "ru": "Готово",
        "es": "Hecho",
        "fr": "Terminé",
        "de": "Fertig",
        "zh-Hans": "完成",
        "ja": "完了",
        "pt": "Concluído",
        "ar": "تم",
        "it": "Fatto"
    },
    "button.delete": {
        "en": "Delete",
        "ru": "Удалить",
        "es": "Eliminar",
        "fr": "Supprimer",
        "de": "Löschen",
        "zh-Hans": "删除",
        "ja": "削除",
        "pt": "Excluir",
        "ar": "حذف",
        "it": "Elimina"
    },
    "button.download": {
        "en": "Download",
        "ru": "Скачать",
        "es": "Descargar",
        "fr": "Télécharger",
        "de": "Herunterladen",
        "zh-Hans": "下载",
        "ja": "ダウンロード",
        "pt": "Baixar",
        "ar": "تنزيل",
        "it": "Scarica"
    },
    "button.upgrade": {
        "en": "Upgrade to Premium",
        "ru": "Перейти на Premium",
        "es": "Actualizar a Premium",
        "fr": "Passer à Premium",
        "de": "Auf Premium upgraden",
        "zh-Hans": "升级到高级版",
        "ja": "プレミアムにアップグレード",
        "pt": "Atualizar para Premium",
        "ar": "الترقية إلى بريميوم",
        "it": "Passa a Premium"
    },
    "button.getStarted": {
        "en": "Get Started",
        "ru": "Начать",
        "es": "Comenzar",
        "fr": "Commencer",
        "de": "Loslegen",
        "zh-Hans": "开始使用",
        "ja": "始める",
        "pt": "Começar",
        "ar": "ابدأ",
        "it": "Inizia"
    },

    # Home View - Greetings
    "home.greeting.morning": {
        "en": "Good Morning!",
        "ru": "Доброе утро!",
        "es": "¡Buenos días!",
        "fr": "Bonjour !",
        "de": "Guten Morgen!",
        "zh-Hans": "早上好！",
        "ja": "おはようございます！",
        "pt": "Bom dia!",
        "ar": "صباح الخير!",
        "it": "Buongiorno!"
    },
    "home.greeting.afternoon": {
        "en": "Good Afternoon!",
        "ru": "Добрый день!",
        "es": "¡Buenas tardes!",
        "fr": "Bon après-midi !",
        "de": "Guten Tag!",
        "zh-Hans": "下午好！",
        "ja": "こんにちは！",
        "pt": "Boa tarde!",
        "ar": "مساء الخير!",
        "it": "Buon pomeriggio!"
    },
    "home.greeting.evening": {
        "en": "Good Evening!",
        "ru": "Добрый вечер!",
        "es": "¡Buenas noches!",
        "fr": "Bonsoir !",
        "de": "Guten Abend!",
        "zh-Hans": "晚上好！",
        "ja": "こんばんは！",
        "pt": "Boa noite!",
        "ar": "مساء الخير!",
        "it": "Buonasera!"
    },
    "home.greeting.night": {
        "en": "Sweet Dreams!",
        "ru": "Сладких снов!",
        "es": "¡Dulces sueños!",
        "fr": "Bonne nuit !",
        "de": "Süße Träume!",
        "zh-Hans": "祝你好梦！",
        "ja": "おやすみなさい！",
        "pt": "Bons sonhos!",
        "ar": "أحلام سعيدة!",
        "it": "Sogni d'oro!"
    },

    # Emergency Cry Detection
    "emergency.title": {
        "en": "Emergency Cry-Stop",
        "ru": "Экстренная остановка плача",
        "es": "Parada de emergencia del llanto",
        "fr": "Arrêt d'urgence des pleurs",
        "de": "Notfall-Weinunterbrechung",
        "zh-Hans": "紧急停止哭泣",
        "ja": "緊急泣き止め",
        "pt": "Parada de emergência do choro",
        "ar": "إيقاف البكاء الطارئ",
        "it": "Arresto di emergenza del pianto"
    },
    "emergency.subtitle": {
        "en": "Instant calming when your baby needs it most",
        "ru": "Мгновенное успокоение, когда малышу это нужно больше всего",
        "es": "Calma instantánea cuando tu bebé más lo necesita",
        "fr": "Apaisement instantané quand votre bébé en a le plus besoin",
        "de": "Sofortige Beruhigung, wenn Ihr Baby es am meisten braucht",
        "zh-Hans": "在宝宝最需要的时候立即安抚",
        "ja": "赤ちゃんが最も必要とするときの即座の落ち着き",
        "pt": "Acalmar instantâneo quando seu bebê mais precisa",
        "ar": "تهدئة فورية عندما يحتاجها طفلك أكثر",
        "it": "Calma istantanea quando il tuo bambino ne ha più bisogno"
    },
    "emergency.startMonitoring": {
        "en": "Start AI Monitoring",
        "ru": "Начать ИИ-мониторинг",
        "es": "Iniciar monitoreo IA",
        "fr": "Démarrer la surveillance IA",
        "de": "KI-Überwachung starten",
        "zh-Hans": "开始AI监测",
        "ja": "AI監視を開始",
        "pt": "Iniciar monitoramento IA",
        "ar": "بدء مراقبة الذكاء الاصطناعي",
        "it": "Avvia monitoraggio IA"
    },
    "emergency.stopMonitoring": {
        "en": "Stop Monitoring",
        "ru": "Остановить мониторинг",
        "es": "Detener monitoreo",
        "fr": "Arrêter la surveillance",
        "de": "Überwachung stoppen",
        "zh-Hans": "停止监测",
        "ja": "監視を停止",
        "pt": "Parar monitoramento",
        "ar": "إيقاف المراقبة",
        "it": "Ferma monitoraggio"
    },
    "emergency.listening": {
        "en": "Listening...",
        "ru": "Прослушивание...",
        "es": "Escuchando...",
        "fr": "Écoute...",
        "de": "Hört zu...",
        "zh-Hans": "正在监听...",
        "ja": "聞いています...",
        "pt": "Ouvindo...",
        "ar": "يستمع...",
        "it": "In ascolto..."
    },

    # Cry Types
    "cry.hunger": {
        "en": "Hunger",
        "ru": "Голод",
        "es": "Hambre",
        "fr": "Faim",
        "de": "Hunger",
        "zh-Hans": "饥饿",
        "ja": "空腹",
        "pt": "Fome",
        "ar": "جوع",
        "it": "Fame"
    },
    "cry.tired": {
        "en": "Tired",
        "ru": "Усталость",
        "es": "Cansancio",
        "fr": "Fatigue",
        "de": "Müdigkeit",
        "zh-Hans": "疲倦",
        "ja": "疲れ",
        "pt": "Cansaço",
        "ar": "تعب",
        "it": "Stanchezza"
    },
    "cry.discomfort": {
        "en": "Discomfort",
        "ru": "Дискомфорт",
        "es": "Molestia",
        "fr": "Inconfort",
        "de": "Unbehagen",
        "zh-Hans": "不适",
        "ja": "不快",
        "pt": "Desconforto",
        "ar": "انزعاج",
        "it": "Disagio"
    },
    "cry.pain": {
        "en": "Pain",
        "ru": "Боль",
        "es": "Dolor",
        "fr": "Douleur",
        "de": "Schmerz",
        "zh-Hans": "疼痛",
        "ja": "痛み",
        "pt": "Dor",
        "ar": "ألم",
        "it": "Dolore"
    },

    # Player View
    "player.nowPlaying": {
        "en": "Now Playing",
        "ru": "Сейчас играет",
        "es": "Reproduciendo ahora",
        "fr": "En cours",
        "de": "Jetzt läuft",
        "zh-Hans": "正在播放",
        "ja": "再生中",
        "pt": "Reproduzindo agora",
        "ar": "قيد التشغيل الآن",
        "it": "In riproduzione"
    },
    "player.upNext": {
        "en": "Up Next",
        "ru": "Далее",
        "es": "A continuación",
        "fr": "À suivre",
        "de": "Als nächstes",
        "zh-Hans": "接下来",
        "ja": "次の曲",
        "pt": "Próximo",
        "ar": "التالي",
        "it": "Prossimo"
    },
    "player.queue": {
        "en": "Queue",
        "ru": "Очередь",
        "es": "Cola",
        "fr": "File d'attente",
        "de": "Warteschlange",
        "zh-Hans": "播放队列",
        "ja": "キュー",
        "pt": "Fila",
        "ar": "قائمة الانتظار",
        "it": "Coda"
    },

    # Empty States
    "empty.noFavorites": {
        "en": "No favorites yet",
        "ru": "Пока нет избранного",
        "es": "Aún no hay favoritos",
        "fr": "Pas encore de favoris",
        "de": "Noch keine Favoriten",
        "zh-Hans": "还没有收藏",
        "ja": "お気に入りはまだありません",
        "pt": "Ainda não há favoritos",
        "ar": "لا توجد مفضلات بعد",
        "it": "Ancora nessun preferito"
    },
    "empty.noPlaylists": {
        "en": "No playlists yet",
        "ru": "Пока нет плейлистов",
        "es": "Aún no hay listas de reproducción",
        "fr": "Pas encore de listes de lecture",
        "de": "Noch keine Playlists",
        "zh-Hans": "还没有播放列表",
        "ja": "プレイリストはまだありません",
        "pt": "Ainda não há playlists",
        "ar": "لا توجد قوائم تشغيل بعد",
        "it": "Ancora nessuna playlist"
    },
    "empty.noDownloads": {
        "en": "No Downloads",
        "ru": "Нет загрузок",
        "es": "Sin descargas",
        "fr": "Aucun téléchargement",
        "de": "Keine Downloads",
        "zh-Hans": "没有下载",
        "ja": "ダウンロードなし",
        "pt": "Sem downloads",
        "ar": "لا توجد تنزيلات",
        "it": "Nessun download"
    },
    "empty.searchNoResults": {
        "en": "No results found",
        "ru": "Ничего не найдено",
        "es": "No se encontraron resultados",
        "fr": "Aucun résultat trouvé",
        "de": "Keine Ergebnisse gefunden",
        "zh-Hans": "未找到结果",
        "ja": "結果が見つかりません",
        "pt": "Nenhum resultado encontrado",
        "ar": "لم يتم العثور على نتائج",
        "it": "Nessun risultato trovato"
    },

    # Categories
    "category.lullabies": {
        "en": "Lullabies",
        "ru": "Колыбельные",
        "es": "Canciones de cuna",
        "fr": "Berceuses",
        "de": "Schlaflieder",
        "zh-Hans": "摇篮曲",
        "ja": "子守唄",
        "pt": "Canções de ninar",
        "ar": "التهويدات",
        "it": "Ninne nanne"
    },
    "category.classical": {
        "en": "Classical Music",
        "ru": "Классическая музыка",
        "es": "Música clásica",
        "fr": "Musique classique",
        "de": "Klassische Musik",
        "zh-Hans": "古典音乐",
        "ja": "クラシック音楽",
        "pt": "Música clássica",
        "ar": "الموسيقى الكلاسيكية",
        "it": "Musica classica"
    },
    "category.nature": {
        "en": "Nature Sounds",
        "ru": "Звуки природы",
        "es": "Sonidos de la naturaleza",
        "fr": "Sons de la nature",
        "de": "Naturgeräusche",
        "zh-Hans": "自然声音",
        "ja": "自然音",
        "pt": "Sons da natureza",
        "ar": "أصوات الطبيعة",
        "it": "Suoni della natura"
    },
    "category.fairyTales": {
        "en": "Fairy Tales",
        "ru": "Сказки",
        "es": "Cuentos de hadas",
        "fr": "Contes de fées",
        "de": "Märchen",
        "zh-Hans": "童话故事",
        "ja": "おとぎ話",
        "pt": "Contos de fadas",
        "ar": "القصص الخيالية",
        "it": "Fiabe"
    },
    "category.ambient": {
        "en": "Ambient",
        "ru": "Эмбиент",
        "es": "Ambiente",
        "fr": "Ambiant",
        "de": "Ambient",
        "zh-Hans": "环境音乐",
        "ja": "アンビエント",
        "pt": "Ambiente",
        "ar": "محيط",
        "it": "Ambient"
    },

    # Settings
    "settings.audio": {
        "en": "Audio Settings",
        "ru": "Настройки аудио",
        "es": "Configuración de audio",
        "fr": "Paramètres audio",
        "de": "Audio-Einstellungen",
        "zh-Hans": "音频设置",
        "ja": "オーディオ設定",
        "pt": "Configurações de áudio",
        "ar": "إعدادات الصوت",
        "it": "Impostazioni audio"
    },
    "settings.volume": {
        "en": "Default Volume",
        "ru": "Громкость по умолчанию",
        "es": "Volumen predeterminado",
        "fr": "Volume par défaut",
        "de": "Standardlautstärke",
        "zh-Hans": "默认音量",
        "ja": "デフォルト音量",
        "pt": "Volume padrão",
        "ar": "مستوى الصوت الافتراضي",
        "it": "Volume predefinito"
    },
    "settings.sleepTimer": {
        "en": "Sleep Timer",
        "ru": "Таймер сна",
        "es": "Temporizador de sueño",
        "fr": "Minuteur de sommeil",
        "de": "Schlaftimer",
        "zh-Hans": "睡眠定时器",
        "ja": "スリープタイマー",
        "pt": "Temporizador de sono",
        "ar": "مؤقت النوم",
        "it": "Timer di riposo"
    },
    "settings.languages": {
        "en": "Languages",
        "ru": "Языки",
        "es": "Idiomas",
        "fr": "Langues",
        "de": "Sprachen",
        "zh-Hans": "语言",
        "ja": "言語",
        "pt": "Idiomas",
        "ar": "اللغات",
        "it": "Lingue"
    },
    "settings.about": {
        "en": "About",
        "ru": "О приложении",
        "es": "Acerca de",
        "fr": "À propos",
        "de": "Über",
        "zh-Hans": "关于",
        "ja": "について",
        "pt": "Sobre",
        "ar": "حول",
        "it": "Informazioni"
    },

    # Onboarding
    "onboarding.welcome": {
        "en": "Welcome to",
        "ru": "Добро пожаловать в",
        "es": "Bienvenido a",
        "fr": "Bienvenue sur",
        "de": "Willkommen bei",
        "zh-Hans": "欢迎使用",
        "ja": "ようこそ",
        "pt": "Bem-vindo ao",
        "ar": "مرحبا بك في",
        "it": "Benvenuto in"
    },
    "onboarding.appName": {
        "en": "Lulla",
        "ru": "Lulla",
        "es": "Lulla",
        "fr": "Lulla",
        "de": "Lulla",
        "zh-Hans": "Lulla",
        "ja": "Lulla",
        "pt": "Lulla",
        "ar": "لولا",
        "it": "Lulla"
    },
    "onboarding.tagline": {
        "en": "Sweet Dreams on Every Ride",
        "ru": "Сладкие сны в каждой поездке",
        "es": "Dulces sueños en cada viaje",
        "fr": "Doux rêves à chaque trajet",
        "de": "Süße Träume bei jeder Fahrt",
        "zh-Hans": "每次旅程都有甜美的梦",
        "ja": "すべての旅に甘い夢を",
        "pt": "Sonhos doces em cada viagem",
        "ar": "أحلام سعيدة في كل رحلة",
        "it": "Sogni d'oro in ogni viaggio"
    },
    "onboarding.subtitle": {
        "en": "AI-powered calming audio for peaceful car rides with your little one",
        "ru": "Успокаивающее аудио с ИИ для спокойных поездок с малышом",
        "es": "Audio calmante con IA para viajes tranquilos con tu pequeño",
        "fr": "Audio apaisant alimenté par l'IA pour des trajets paisibles avec votre petit",
        "de": "KI-gestützte beruhigende Audioaufnahmen für friedliche Autofahrten mit Ihrem Kleinen",
        "zh-Hans": "AI驱动的安抚音频，为您和宝宝带来平和的旅程",
        "ja": "お子様との穏やかなドライブのためのAI搭載の落ち着く音声",
        "pt": "Áudio calmante alimentado por IA para viagens tranquilas com seu pequeno",
        "ar": "صوت مهدئ مدعوم بالذكاء الاصطناعي لرحلات سيارة هادئة مع طفلك الصغير",
        "it": "Audio rilassante alimentato dall'IA per viaggi in auto tranquilli con il tuo piccolo"
    },

    # Premium Features
    "premium.unlockAll": {
        "en": "Unlock all content & features",
        "ru": "Разблокировать весь контент и функции",
        "es": "Desbloquear todo el contenido y funciones",
        "fr": "Débloquer tout le contenu et les fonctionnalités",
        "de": "Alle Inhalte und Funktionen freischalten",
        "zh-Hans": "解锁所有内容和功能",
        "ja": "すべてのコンテンツと機能のロックを解除",
        "pt": "Desbloquear todo o conteúdo e recursos",
        "ar": "فتح جميع المحتويات والميزات",
        "it": "Sblocca tutti i contenuti e le funzionalità"
    },
    "premium.free": {
        "en": "Free",
        "ru": "Бесплатно",
        "es": "Gratis",
        "fr": "Gratuit",
        "de": "Kostenlos",
        "zh-Hans": "免费",
        "ja": "無料",
        "pt": "Grátis",
        "ar": "مجاني",
        "it": "Gratuito"
    },
    "premium.premium": {
        "en": "Premium",
        "ru": "Премиум",
        "es": "Premium",
        "fr": "Premium",
        "de": "Premium",
        "zh-Hans": "高级版",
        "ja": "プレミアム",
        "pt": "Premium",
        "ar": "بريميوم",
        "it": "Premium"
    },

    # Time and Duration
    "time.minutes": {
        "en": "min",
        "ru": "мин",
        "es": "min",
        "fr": "min",
        "de": "Min",
        "zh-Hans": "分钟",
        "ja": "分",
        "pt": "min",
        "ar": "دقيقة",
        "it": "min"
    },
    "time.hours": {
        "en": "h",
        "ru": "ч",
        "es": "h",
        "fr": "h",
        "de": "Std",
        "zh-Hans": "小时",
        "ja": "時間",
        "pt": "h",
        "ar": "ساعة",
        "it": "h"
    },

    # Common Actions
    "action.addToFavorites": {
        "en": "Add to Favorites",
        "ru": "Добавить в избранное",
        "es": "Añadir a favoritos",
        "fr": "Ajouter aux favoris",
        "de": "Zu Favoriten hinzufügen",
        "zh-Hans": "添加到收藏",
        "ja": "お気に入りに追加",
        "pt": "Adicionar aos favoritos",
        "ar": "إضافة إلى المفضلة",
        "it": "Aggiungi ai preferiti"
    },
    "action.removeFromFavorites": {
        "en": "Remove from Favorites",
        "ru": "Удалить из избранного",
        "es": "Eliminar de favoritos",
        "fr": "Retirer des favoris",
        "de": "Aus Favoriten entfernen",
        "zh-Hans": "从收藏中移除",
        "ja": "お気に入りから削除",
        "pt": "Remover dos favoritos",
        "ar": "إزالة من المفضلة",
        "it": "Rimuovi dai preferiti"
    },
    "action.addToPlaylist": {
        "en": "Add to Playlist",
        "ru": "Добавить в плейлист",
        "es": "Añadir a lista de reproducción",
        "fr": "Ajouter à la liste de lecture",
        "de": "Zur Playlist hinzufügen",
        "zh-Hans": "添加到播放列表",
        "ja": "プレイリストに追加",
        "pt": "Adicionar à playlist",
        "ar": "إضافة إلى قائمة التشغيل",
        "it": "Aggiungi alla playlist"
    },

    # Alert Messages
    "alert.error": {
        "en": "Error",
        "ru": "Ошибка",
        "es": "Error",
        "fr": "Erreur",
        "de": "Fehler",
        "zh-Hans": "错误",
        "ja": "エラー",
        "pt": "Erro",
        "ar": "خطأ",
        "it": "Errore"
    },
    "alert.confirm": {
        "en": "Confirm",
        "ru": "Подтвердить",
        "es": "Confirmar",
        "fr": "Confirmer",
        "de": "Bestätigen",
        "zh-Hans": "确认",
        "ja": "確認",
        "pt": "Confirmar",
        "ar": "تأكيد",
        "it": "Conferma"
    },
    "alert.deletePlaylist": {
        "en": "Delete Playlist?",
        "ru": "Удалить плейлист?",
        "es": "¿Eliminar lista de reproducción?",
        "fr": "Supprimer la liste de lecture ?",
        "de": "Playlist löschen?",
        "zh-Hans": "删除播放列表？",
        "ja": "プレイリストを削除しますか？",
        "pt": "Excluir playlist?",
        "ar": "حذف قائمة التشغيل؟",
        "it": "Eliminare la playlist?"
    },

    # Status Labels
    "status.downloading": {
        "en": "Downloading...",
        "ru": "Загрузка...",
        "es": "Descargando...",
        "fr": "Téléchargement...",
        "de": "Wird heruntergeladen...",
        "zh-Hans": "下载中...",
        "ja": "ダウンロード中...",
        "pt": "Baixando...",
        "ar": "جارٍ التنزيل...",
        "it": "Scaricamento..."
    },
    "status.loading": {
        "en": "Loading...",
        "ru": "Загрузка...",
        "es": "Cargando...",
        "fr": "Chargement...",
        "de": "Lädt...",
        "zh-Hans": "加载中...",
        "ja": "読み込み中...",
        "pt": "Carregando...",
        "ar": "جارٍ التحميل...",
        "it": "Caricamento..."
    },
    "status.ready": {
        "en": "Ready",
        "ru": "Готово",
        "es": "Listo",
        "fr": "Prêt",
        "de": "Bereit",
        "zh-Hans": "就绪",
        "ja": "準備完了",
        "pt": "Pronto",
        "ar": "جاهز",
        "it": "Pronto"
    },

    # Insights
    "insights.overview": {
        "en": "Overview",
        "ru": "Обзор",
        "es": "Resumen",
        "fr": "Aperçu",
        "de": "Übersicht",
        "zh-Hans": "概览",
        "ja": "概要",
        "pt": "Visão geral",
        "ar": "نظرة عامة",
        "it": "Panoramica"
    },
    "insights.sessions": {
        "en": "Sessions",
        "ru": "Сессии",
        "es": "Sesiones",
        "fr": "Sessions",
        "de": "Sitzungen",
        "zh-Hans": "会话",
        "ja": "セッション",
        "pt": "Sessões",
        "ar": "الجلسات",
        "it": "Sessioni"
    },
    "insights.accuracy": {
        "en": "Accuracy",
        "ru": "Точность",
        "es": "Precisión",
        "fr": "Précision",
        "de": "Genauigkeit",
        "zh-Hans": "准确度",
        "ja": "精度",
        "pt": "Precisão",
        "ar": "الدقة",
        "it": "Precisione"
    },
    "insights.confidence": {
        "en": "Confidence",
        "ru": "Уверенность",
        "es": "Confianza",
        "fr": "Confiance",
        "de": "Vertrauen",
        "zh-Hans": "置信度",
        "ja": "信頼度",
        "pt": "Confiança",
        "ar": "الثقة",
        "it": "Confidenza"
    },

    # Baby Profile
    "baby.name": {
        "en": "Name",
        "ru": "Имя",
        "es": "Nombre",
        "fr": "Nom",
        "de": "Name",
        "zh-Hans": "名字",
        "ja": "名前",
        "pt": "Nome",
        "ar": "الاسم",
        "it": "Nome"
    },
    "baby.birthDate": {
        "en": "Birth Date",
        "ru": "Дата рождения",
        "es": "Fecha de nacimiento",
        "fr": "Date de naissance",
        "de": "Geburtsdatum",
        "zh-Hans": "出生日期",
        "ja": "生年月日",
        "pt": "Data de nascimento",
        "ar": "تاريخ الميلاد",
        "it": "Data di nascita"
    },
    "baby.age": {
        "en": "Current Age",
        "ru": "Текущий возраст",
        "es": "Edad actual",
        "fr": "Âge actuel",
        "de": "Aktuelles Alter",
        "zh-Hans": "当前年龄",
        "ja": "現在の年齢",
        "pt": "Idade atual",
        "ar": "العمر الحالي",
        "it": "Età attuale"
    },

    # Search
    "search.placeholder": {
        "en": "Search fairy tales, lullabies...",
        "ru": "Поиск сказок, колыбельных...",
        "es": "Buscar cuentos, canciones de cuna...",
        "fr": "Rechercher des contes, berceuses...",
        "de": "Märchen, Schlaflieder suchen...",
        "zh-Hans": "搜索童话、摇篮曲...",
        "ja": "おとぎ話、子守唄を検索...",
        "pt": "Pesquisar contos de fadas, canções de ninar...",
        "ar": "البحث عن حكايات، تهويدات...",
        "it": "Cerca fiabe, ninne nanne..."
    },
    "search.recent": {
        "en": "Recent",
        "ru": "Недавние",
        "es": "Recientes",
        "fr": "Récents",
        "de": "Zuletzt",
        "zh-Hans": "最近",
        "ja": "最近",
        "pt": "Recentes",
        "ar": "الأخيرة",
        "it": "Recenti"
    },
    "search.popular": {
        "en": "Popular",
        "ru": "Популярные",
        "es": "Populares",
        "fr": "Populaires",
        "de": "Beliebt",
        "zh-Hans": "热门",
        "ja": "人気",
        "pt": "Populares",
        "ar": "الشائعة",
        "it": "Popolari"
    }
}


def create_localization_entry(key: str, translations: Dict[str, str]) -> Dict:
    """Create a single localization entry for xcstrings format"""
    localizations = {}
    for lang_code, translation in translations.items():
        localizations[lang_code] = {
            "stringUnit": {
                "state": "translated",
                "value": translation
            }
        }

    return {
        "extractionState": "manual",
        "localizations": localizations
    }


def generate_xcstrings():
    """Generate the complete xcstrings file"""
    xcstrings = {
        "sourceLanguage": "en",
        "strings": {},
        "version": "1.0"
    }

    # Add all translations
    for key, translations in TRANSLATIONS.items():
        xcstrings["strings"][key] = create_localization_entry(key, translations)

    return xcstrings


def main():
    """Main execution"""
    print("Generating comprehensive localization file...")
    xcstrings = generate_xcstrings()

    output_path = "BabyInCarApp/BabyInCarApp/Localizable.xcstrings"
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(xcstrings, f, ensure_ascii=False, indent=2)

    print(f"✅ Generated {output_path}")
    print(f"📊 Total strings: {len(TRANSLATIONS)}")
    print(f"🌍 Languages: 10 (en, ru, es, fr, de, zh-Hans, ja, pt, ar, it)")
    print(f"📝 Total translations: {len(TRANSLATIONS) * 10}")


if __name__ == "__main__":
    main()
