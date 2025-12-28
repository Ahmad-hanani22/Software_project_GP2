// 🔔 Firebase Cloud Messaging Service Worker
// هذا الملف ضروري لعمل إشعارات Firebase على الويب

// Firebase configuration (تم تحديثها من Firebase Console)
const firebaseConfig = {
  apiKey: "AIzaSyC-4Ks0gQj86FbHIKMxbW-V9biIgR2C7nI",
  authDomain: "shaqati-e900c.firebaseapp.com",
  projectId: "shaqati-e900c",
  storageBucket: "shaqati-e900c.firebasestorage.app",
  messagingSenderId: "214403166778",
  appId: "1:214403166778:web:093cac0fa3382e9835fb03",
  measurementId: "G-5QZ49VNLQ1"
};

// Import Firebase scripts (يتم تحميلها من CDN في index.html)
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js');

// Initialize Firebase
firebase.initializeApp(firebaseConfig);

// Retrieve an instance of Firebase Messaging so that it can handle background messages
const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
  console.log('🔔 [Service Worker] Background message received:', payload);

  const notificationTitle = payload.notification?.title || 'SHAQATI';
  const notificationOptions = {
    body: payload.notification?.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: payload.data?.type || 'notification',
    data: payload.data || {},
    requireInteraction: false,
    silent: false,
    vibrate: [200, 100, 200],
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// Handle notification click
self.addEventListener('notificationclick', (event) => {
  console.log('🔔 [Service Worker] Notification clicked:', event);
  
  event.notification.close();

  // يمكنك إضافة logic للتنقل إلى صفحة معينة عند النقر على الإشعار
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      // إذا كان التطبيق مفتوحاً، افتح النافذة
      for (const client of clientList) {
        if (client.url === '/' && 'focus' in client) {
          return client.focus();
        }
      }
      // إذا لم يكن مفتوحاً، افتح نافذة جديدة
      if (clients.openWindow) {
        return clients.openWindow('/');
      }
    })
  );
});

