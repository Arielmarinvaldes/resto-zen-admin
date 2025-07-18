import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";

// Inicializa el SDK de Firebase Admin para poder interactuar con los servicios de Firebase.
admin.initializeApp();

/**
 * Cloud Function (V2) que se activa cuando se crea un nuevo documento en la colección 'restaurants'.
 */
export const onnewrestaurantrequest = onDocumentCreated("restaurants/{restaurantId}", async (event) => {
  // El snapshot del documento creado está en event.data.
  const snapshot = event.data;
  if (!snapshot) {
    console.log("No data associated with the event");
    return;
  }

  // Obtiene los datos del restaurante recién creado.
  const restaurantData = snapshot.data();
  const restaurantId = event.params.restaurantId;

  // Comprueba si el restaurante tiene el estado 'pending'.
  // Si no lo tiene, o si el documento no tiene datos, la función termina.
  if (!restaurantData || restaurantData.status !== "pending") {
    console.log(
      `El restaurante ${restaurantId} no está pendiente de aprobación. No se envía notificación.`
    );
    return;
  }

  console.log(
    `Nuevo restaurante pendiente: ${restaurantData.restaurantName}. Enviando notificación.`
  );

  // Define el contenido de la notificación push.
  const payload = {
    notification: {
      title: "Nueva Solicitud de Registro",
      body: `El restaurante '${restaurantData.restaurantName}' está pendiente de aprobación.`,
      click_action: "FLUTTER_NOTIFICATION_CLICK", // Acción para la app móvil.
    },
    data: {
      // Puedes enviar datos adicionales si la app móvil los necesita.
      restaurantId: restaurantId,
      screen: "/approval", // Sugerencia para redirigir en la app móvil.
    },
  };

  // Define el "topic" al que se enviará la notificación.
  // Los dispositivos de los administradores deben estar suscritos a este topic.
  const topic = "pending_approvals";

  try {
    // Envía el mensaje al topic especificado.
    const response = await admin.messaging().sendToTopic(topic, payload);
    console.log("Notificación enviada con éxito:", response);
    return response;
  } catch (error) {
    console.error("Error al enviar la notificación:", error);
    return;
  }
});
