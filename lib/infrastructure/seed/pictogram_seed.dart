/// Datos iniciales (SEED) de SQLite.
///
/// Son los pictogramas y categorias que ya tenia el prototipo (espanol,
/// contexto Lima), representados con emojis para funcionar 100 % offline.
/// Se insertan una sola vez al crear la base de datos. Un perfil nuevo
/// los tiene todos seleccionados; el tutor puede ocultarlos sin
/// eliminarlos del catalogo (HU015).
library;

/// Categoria semilla. [id] es el `id_categoria` con el que se inserta.
class SeedCategory {
  final int id;
  final String key;
  final String name;
  const SeedCategory(this.id, this.key, this.name);
}

/// Pictograma semilla. [key] es un identificador estable del seed (no se
/// guarda en la base de datos; sirve para enlazar los gestos iniciales).
class SeedPictogram {
  final String key;
  final String label;
  final String emoji;
  final String categoryKey;
  final String speech;
  const SeedPictogram({
    required this.key,
    required this.label,
    required this.emoji,
    required this.categoryKey,
    required this.speech,
  });
}

const List<SeedCategory> kSeedCategories = [
  SeedCategory(1, 'basicas', 'Necesidades'),
  SeedCategory(2, 'emociones', 'Emociones'),
  SeedCategory(3, 'salud', 'Salud y dolor'),
  SeedCategory(4, 'higiene', 'Higiene'),
  SeedCategory(5, 'comida', 'Comida y bebida'),
  SeedCategory(6, 'actividades', 'Actividades'),
  SeedCategory(7, 'personas', 'Personas'),
  SeedCategory(8, 'lugares', 'Lugares'),
  SeedCategory(9, 'social', 'Social'),
  SeedCategory(10, 'rutina', 'Rutina y tiempo'),
];

const List<SeedPictogram> kSeedPictograms = [
  // ---------------- NECESIDADES BASICAS ----------------
  SeedPictogram(key: 'b_bano', label: 'Baño', emoji: '🚽', categoryKey: 'basicas', speech: 'Quiero ir al baño'),
  SeedPictogram(key: 'b_pipi', label: 'Hacer pipí', emoji: '💦', categoryKey: 'basicas', speech: 'Tengo que hacer pipí'),
  SeedPictogram(key: 'b_caca', label: 'Hacer caca', emoji: '💩', categoryKey: 'basicas', speech: 'Tengo que hacer caca'),
  SeedPictogram(key: 'b_agua', label: 'Agua', emoji: '💧', categoryKey: 'basicas', speech: 'Quiero agua'),
  SeedPictogram(key: 'b_sed', label: 'Sed', emoji: '🥤', categoryKey: 'basicas', speech: 'Tengo sed'),
  SeedPictogram(key: 'b_hambre', label: 'Hambre', emoji: '🍽️', categoryKey: 'basicas', speech: 'Tengo hambre'),
  SeedPictogram(key: 'b_dormir', label: 'Dormir', emoji: '🛏️', categoryKey: 'basicas', speech: 'Quiero dormir'),
  SeedPictogram(key: 'b_cansado', label: 'Cansado', emoji: '😴', categoryKey: 'basicas', speech: 'Estoy cansado'),
  SeedPictogram(key: 'b_descanso', label: 'Descanso', emoji: '⏸️', categoryKey: 'basicas', speech: 'Necesito un descanso'),
  SeedPictogram(key: 'b_ayuda', label: 'Ayuda', emoji: '🆘', categoryKey: 'basicas', speech: 'Necesito ayuda'),
  SeedPictogram(key: 'b_abrazo', label: 'Abrazo', emoji: '🤗', categoryKey: 'basicas', speech: 'Quiero un abrazo'),
  SeedPictogram(key: 'b_frio', label: 'Frío', emoji: '🥶', categoryKey: 'basicas', speech: 'Tengo frío'),
  SeedPictogram(key: 'b_calor', label: 'Calor', emoji: '🥵', categoryKey: 'basicas', speech: 'Tengo calor'),
  SeedPictogram(key: 'b_ropa', label: 'Cambiar ropa', emoji: '👕', categoryKey: 'basicas', speech: 'Quiero cambiarme de ropa'),
  SeedPictogram(key: 'b_ruido', label: 'Mucho ruido', emoji: '🔊', categoryKey: 'basicas', speech: 'Hay mucho ruido'),
  SeedPictogram(key: 'b_silencio', label: 'Silencio', emoji: '🤫', categoryKey: 'basicas', speech: 'Quiero silencio'),
  SeedPictogram(key: 'b_luz', label: 'Mucha luz', emoji: '💡', categoryKey: 'basicas', speech: 'Hay mucha luz'),
  SeedPictogram(key: 'b_solo', label: 'Estar solo', emoji: '🧍', categoryKey: 'basicas', speech: 'Quiero estar solo un rato'),
  // ---------------- EMOCIONES ----------------
  SeedPictogram(key: 'e_feliz', label: 'Feliz', emoji: '😄', categoryKey: 'emociones', speech: 'Estoy feliz'),
  SeedPictogram(key: 'e_triste', label: 'Triste', emoji: '😢', categoryKey: 'emociones', speech: 'Estoy triste'),
  SeedPictogram(key: 'e_enojado', label: 'Enojado', emoji: '😠', categoryKey: 'emociones', speech: 'Estoy enojado'),
  SeedPictogram(key: 'e_asustado', label: 'Asustado', emoji: '😨', categoryKey: 'emociones', speech: 'Tengo miedo'),
  SeedPictogram(key: 'e_tranquilo', label: 'Tranquilo', emoji: '😌', categoryKey: 'emociones', speech: 'Estoy tranquilo'),
  SeedPictogram(key: 'e_nervioso', label: 'Nervioso', emoji: '😰', categoryKey: 'emociones', speech: 'Estoy nervioso'),
  SeedPictogram(key: 'e_aburrido', label: 'Aburrido', emoji: '🥱', categoryKey: 'emociones', speech: 'Estoy aburrido'),
  SeedPictogram(key: 'e_frustrado', label: 'Frustrado', emoji: '😤', categoryKey: 'emociones', speech: 'Estoy frustrado'),
  SeedPictogram(key: 'e_emocionado', label: 'Emocionado', emoji: '🤩', categoryKey: 'emociones', speech: 'Estoy emocionado'),
  SeedPictogram(key: 'e_sorprendido', label: 'Sorprendido', emoji: '😮', categoryKey: 'emociones', speech: 'Estoy sorprendido'),
  SeedPictogram(key: 'e_verguenza', label: 'Con vergüenza', emoji: '😳', categoryKey: 'emociones', speech: 'Tengo vergüenza'),
  SeedPictogram(key: 'e_orgulloso', label: 'Orgulloso', emoji: '😎', categoryKey: 'emociones', speech: 'Estoy orgulloso de mí'),
  // ---------------- SALUD Y DOLOR ----------------
  SeedPictogram(key: 's_dolor', label: 'Me duele', emoji: '🤕', categoryKey: 'salud', speech: 'Me duele algo'),
  SeedPictogram(key: 's_cabeza', label: 'Cabeza', emoji: '🧠', categoryKey: 'salud', speech: 'Me duele la cabeza'),
  SeedPictogram(key: 's_barriga', label: 'Barriga', emoji: '🤢', categoryKey: 'salud', speech: 'Me duele la barriga'),
  SeedPictogram(key: 's_garganta', label: 'Garganta', emoji: '😷', categoryKey: 'salud', speech: 'Me duele la garganta'),
  SeedPictogram(key: 's_diente', label: 'Diente', emoji: '🦷', categoryKey: 'salud', speech: 'Me duele un diente'),
  SeedPictogram(key: 's_oido', label: 'Oído', emoji: '👂', categoryKey: 'salud', speech: 'Me duele el oído'),
  SeedPictogram(key: 's_mareo', label: 'Mareo', emoji: '😵‍💫', categoryKey: 'salud', speech: 'Estoy mareado'),
  SeedPictogram(key: 's_picazon', label: 'Picazón', emoji: '🐜', categoryKey: 'salud', speech: 'Me pica'),
  SeedPictogram(key: 's_curita', label: 'Curita', emoji: '🩹', categoryKey: 'salud', speech: 'Necesito una curita'),
  SeedPictogram(key: 's_medicina', label: 'Medicina', emoji: '💊', categoryKey: 'salud', speech: 'Me toca la medicina'),
  SeedPictogram(key: 's_doctor', label: 'Doctor', emoji: '🩺', categoryKey: 'salud', speech: 'Quiero ver al doctor'),
  SeedPictogram(key: 's_vomito', label: 'Ganas de vomitar', emoji: '🤮', categoryKey: 'salud', speech: 'Tengo ganas de vomitar'),
  // ---------------- HIGIENE ----------------
  SeedPictogram(key: 'h_manos', label: 'Lavar manos', emoji: '🧼', categoryKey: 'higiene', speech: 'Quiero lavarme las manos'),
  SeedPictogram(key: 'h_dientes', label: 'Cepillar dientes', emoji: '🪥', categoryKey: 'higiene', speech: 'Voy a cepillarme los dientes'),
  SeedPictogram(key: 'h_banarse', label: 'Bañarse', emoji: '🛁', categoryKey: 'higiene', speech: 'Quiero bañarme'),
  SeedPictogram(key: 'h_nariz', label: 'Sonarse la nariz', emoji: '🤧', categoryKey: 'higiene', speech: 'Necesito sonarme la nariz'),
  SeedPictogram(key: 'h_peine', label: 'Peinarse', emoji: '💇', categoryKey: 'higiene', speech: 'Quiero peinarme'),
  SeedPictogram(key: 'h_panal', label: 'Cambiar pañal', emoji: '🧷', categoryKey: 'higiene', speech: 'Necesito que me cambien'),
  SeedPictogram(key: 'h_toalla', label: 'Toalla', emoji: '🧻', categoryKey: 'higiene', speech: 'Necesito una toalla'),
  SeedPictogram(key: 'h_secar', label: 'Secarse', emoji: '💨', categoryKey: 'higiene', speech: 'Quiero secarme'),
  // ---------------- COMIDA Y BEBIDA ----------------
  SeedPictogram(key: 'c_comer', label: 'Comer', emoji: '🍴', categoryKey: 'comida', speech: 'Quiero comer'),
  SeedPictogram(key: 'c_pan', label: 'Pan', emoji: '🍞', categoryKey: 'comida', speech: 'Quiero pan'),
  SeedPictogram(key: 'c_leche', label: 'Leche', emoji: '🥛', categoryKey: 'comida', speech: 'Quiero leche'),
  SeedPictogram(key: 'c_jugo', label: 'Jugo', emoji: '🧃', categoryKey: 'comida', speech: 'Quiero jugo'),
  SeedPictogram(key: 'c_manzana', label: 'Manzana', emoji: '🍎', categoryKey: 'comida', speech: 'Quiero una manzana'),
  SeedPictogram(key: 'c_platano', label: 'Plátano', emoji: '🍌', categoryKey: 'comida', speech: 'Quiero un plátano'),
  SeedPictogram(key: 'c_arroz', label: 'Arroz', emoji: '🍚', categoryKey: 'comida', speech: 'Quiero arroz'),
  SeedPictogram(key: 'c_pollo', label: 'Pollo', emoji: '🍗', categoryKey: 'comida', speech: 'Quiero pollo'),
  SeedPictogram(key: 'c_sopa', label: 'Sopa', emoji: '🍲', categoryKey: 'comida', speech: 'Quiero sopa'),
  SeedPictogram(key: 'c_galleta', label: 'Galleta', emoji: '🍪', categoryKey: 'comida', speech: 'Quiero una galleta'),
  SeedPictogram(key: 'c_yogur', label: 'Yogur', emoji: '🥣', categoryKey: 'comida', speech: 'Quiero yogur'),
  SeedPictogram(key: 'c_fruta', label: 'Fruta', emoji: '🍓', categoryKey: 'comida', speech: 'Quiero fruta'),
  SeedPictogram(key: 'c_mas', label: 'Más comida', emoji: '➕', categoryKey: 'comida', speech: 'Quiero más'),
  SeedPictogram(key: 'c_nomas', label: 'Ya no quiero', emoji: '🚫', categoryKey: 'comida', speech: 'Ya no quiero más'),
  // ---------------- ACTIVIDADES ----------------
  SeedPictogram(key: 'a_jugar', label: 'Jugar', emoji: '🧸', categoryKey: 'actividades', speech: 'Quiero jugar'),
  SeedPictogram(key: 'a_pintar', label: 'Pintar', emoji: '🎨', categoryKey: 'actividades', speech: 'Quiero pintar'),
  SeedPictogram(key: 'a_musica', label: 'Música', emoji: '🎵', categoryKey: 'actividades', speech: 'Quiero escuchar música'),
  SeedPictogram(key: 'a_leer', label: 'Cuento', emoji: '📖', categoryKey: 'actividades', speech: 'Quiero un cuento'),
  SeedPictogram(key: 'a_video', label: 'Video', emoji: '📺', categoryKey: 'actividades', speech: 'Quiero ver un video'),
  SeedPictogram(key: 'a_tablet', label: 'Tablet', emoji: '📱', categoryKey: 'actividades', speech: 'Quiero la tablet'),
  SeedPictogram(key: 'a_pelota', label: 'Pelota', emoji: '⚽', categoryKey: 'actividades', speech: 'Quiero jugar con la pelota'),
  SeedPictogram(key: 'a_bloques', label: 'Bloques', emoji: '🧱', categoryKey: 'actividades', speech: 'Quiero armar bloques'),
  SeedPictogram(key: 'a_rompecabezas', label: 'Rompecabezas', emoji: '🧩', categoryKey: 'actividades', speech: 'Quiero un rompecabezas'),
  SeedPictogram(key: 'a_columpio', label: 'Columpio', emoji: '🛝', categoryKey: 'actividades', speech: 'Quiero el columpio'),
  SeedPictogram(key: 'a_salir', label: 'Salir', emoji: '🚶', categoryKey: 'actividades', speech: 'Quiero salir'),
  SeedPictogram(key: 'a_bailar', label: 'Bailar', emoji: '🕺', categoryKey: 'actividades', speech: 'Quiero bailar'),
  SeedPictogram(key: 'a_otra', label: 'Otra cosa', emoji: '🔄', categoryKey: 'actividades', speech: 'Quiero hacer otra cosa'),
  // ---------------- PERSONAS ----------------
  SeedPictogram(key: 'p_mama', label: 'Mamá', emoji: '👩', categoryKey: 'personas', speech: 'Quiero a mamá'),
  SeedPictogram(key: 'p_papa', label: 'Papá', emoji: '👨', categoryKey: 'personas', speech: 'Quiero a papá'),
  SeedPictogram(key: 'p_hermano', label: 'Hermano', emoji: '👦', categoryKey: 'personas', speech: 'Quiero a mi hermano'),
  SeedPictogram(key: 'p_hermana', label: 'Hermana', emoji: '👧', categoryKey: 'personas', speech: 'Quiero a mi hermana'),
  SeedPictogram(key: 'p_abuela', label: 'Abuela', emoji: '👵', categoryKey: 'personas', speech: 'Quiero a mi abuela'),
  SeedPictogram(key: 'p_abuelo', label: 'Abuelo', emoji: '👴', categoryKey: 'personas', speech: 'Quiero a mi abuelo'),
  SeedPictogram(key: 'p_profe', label: 'Profesora', emoji: '👩‍🏫', categoryKey: 'personas', speech: 'Quiero a la profesora'),
  SeedPictogram(key: 'p_terapeuta', label: 'Terapeuta', emoji: '🧑‍⚕️', categoryKey: 'personas', speech: 'Quiero al terapeuta'),
  SeedPictogram(key: 'p_amigo', label: 'Amigo', emoji: '🧒', categoryKey: 'personas', speech: 'Quiero jugar con mi amigo'),
  SeedPictogram(key: 'p_tia', label: 'Tía', emoji: '👩‍🦱', categoryKey: 'personas', speech: 'Quiero a mi tía'),
  SeedPictogram(key: 'p_tio', label: 'Tío', emoji: '👨‍🦱', categoryKey: 'personas', speech: 'Quiero a mi tío'),
  // ---------------- LUGARES ----------------
  SeedPictogram(key: 'l_casa', label: 'Casa', emoji: '🏠', categoryKey: 'lugares', speech: 'Quiero ir a casa'),
  SeedPictogram(key: 'l_colegio', label: 'Colegio', emoji: '🏫', categoryKey: 'lugares', speech: 'Vamos al colegio'),
  SeedPictogram(key: 'l_aula', label: 'Aula', emoji: '🪑', categoryKey: 'lugares', speech: 'Vamos al aula'),
  SeedPictogram(key: 'l_bano', label: 'Baño', emoji: '🚻', categoryKey: 'lugares', speech: 'Vamos al baño'),
  SeedPictogram(key: 'l_patio', label: 'Patio', emoji: '🌤️', categoryKey: 'lugares', speech: 'Quiero ir al patio'),
  SeedPictogram(key: 'l_parque', label: 'Parque', emoji: '🌳', categoryKey: 'lugares', speech: 'Quiero ir al parque'),
  SeedPictogram(key: 'l_cocina', label: 'Cocina', emoji: '🍳', categoryKey: 'lugares', speech: 'Vamos a la cocina'),
  SeedPictogram(key: 'l_cuarto', label: 'Mi cuarto', emoji: '🚪', categoryKey: 'lugares', speech: 'Quiero ir a mi cuarto'),
  SeedPictogram(key: 'l_carro', label: 'Carro', emoji: '🚗', categoryKey: 'lugares', speech: 'Vamos en el carro'),
  SeedPictogram(key: 'l_calle', label: 'Calle', emoji: '🛣️', categoryKey: 'lugares', speech: 'Vamos a la calle'),
  // ---------------- SOCIAL Y RESPUESTAS ----------------
  SeedPictogram(key: 'r_si', label: 'Sí', emoji: '👍', categoryKey: 'social', speech: 'Sí'),
  SeedPictogram(key: 'r_no', label: 'No', emoji: '👎', categoryKey: 'social', speech: 'No'),
  SeedPictogram(key: 'r_quiero', label: 'Quiero', emoji: '🙌', categoryKey: 'social', speech: 'Yo quiero'),
  SeedPictogram(key: 'r_noquiero', label: 'No quiero', emoji: '🙅', categoryKey: 'social', speech: 'No quiero'),
  SeedPictogram(key: 'r_parar', label: 'Parar', emoji: '✋', categoryKey: 'social', speech: 'Para, por favor'),
  SeedPictogram(key: 'r_mas', label: 'Más', emoji: '➕', categoryKey: 'social', speech: 'Quiero más'),
  SeedPictogram(key: 'r_termine', label: 'Terminé', emoji: '🏁', categoryKey: 'social', speech: 'Ya terminé'),
  SeedPictogram(key: 'r_espera', label: 'Espera', emoji: '⏳', categoryKey: 'social', speech: 'Espera un momento'),
  SeedPictogram(key: 'r_miturno', label: 'Mi turno', emoji: '🙋', categoryKey: 'social', speech: 'Es mi turno'),
  SeedPictogram(key: 'r_tuturno', label: 'Tu turno', emoji: '👉', categoryKey: 'social', speech: 'Es tu turno'),
  SeedPictogram(key: 'r_mira', label: 'Mira', emoji: '👀', categoryKey: 'social', speech: 'Mira'),
  SeedPictogram(key: 'r_ven', label: 'Ven', emoji: '🫸', categoryKey: 'social', speech: 'Ven, por favor'),
  SeedPictogram(key: 'r_hola', label: 'Hola', emoji: '👋', categoryKey: 'social', speech: 'Hola'),
  SeedPictogram(key: 'r_adios', label: 'Adiós', emoji: '🤚', categoryKey: 'social', speech: 'Adiós'),
  SeedPictogram(key: 'r_gracias', label: 'Gracias', emoji: '🙏', categoryKey: 'social', speech: 'Gracias'),
  SeedPictogram(key: 'r_porfavor', label: 'Por favor', emoji: '🫱', categoryKey: 'social', speech: 'Por favor'),
  SeedPictogram(key: 'r_noentiendo', label: 'No entiendo', emoji: '❓', categoryKey: 'social', speech: 'No entiendo'),
  SeedPictogram(key: 'r_nose', label: 'No sé', emoji: '🤷', categoryKey: 'social', speech: 'No sé'),
  // ---------------- RUTINA Y TIEMPO ----------------
  SeedPictogram(key: 't_ahora', label: 'Ahora', emoji: '⏰', categoryKey: 'rutina', speech: 'Ahora'),
  SeedPictogram(key: 't_despues', label: 'Después', emoji: '⏭️', categoryKey: 'rutina', speech: 'Después'),
  SeedPictogram(key: 't_primero', label: 'Primero', emoji: '1️⃣', categoryKey: 'rutina', speech: 'Primero'),
  SeedPictogram(key: 't_luego', label: 'Luego', emoji: '2️⃣', categoryKey: 'rutina', speech: 'Luego'),
  SeedPictogram(key: 't_hoy', label: 'Hoy', emoji: '📅', categoryKey: 'rutina', speech: 'Hoy'),
  SeedPictogram(key: 't_manana', label: 'Mañana', emoji: '🌅', categoryKey: 'rutina', speech: 'Mañana'),
  SeedPictogram(key: 't_comer', label: 'Hora de comer', emoji: '🍽️', categoryKey: 'rutina', speech: 'Es hora de comer'),
  SeedPictogram(key: 't_dormir', label: 'Hora de dormir', emoji: '🌙', categoryKey: 'rutina', speech: 'Es hora de dormir'),
  SeedPictogram(key: 't_clase', label: 'Hora de clase', emoji: '🔔', categoryKey: 'rutina', speech: 'Es hora de la clase'),
  SeedPictogram(key: 't_terminado', label: 'Terminado', emoji: '✅', categoryKey: 'rutina', speech: 'Esto ya está terminado'),
  SeedPictogram(key: 't_casa', label: 'Hora de ir a casa', emoji: '🏡', categoryKey: 'rutina', speech: 'Es hora de ir a casa'),
];
