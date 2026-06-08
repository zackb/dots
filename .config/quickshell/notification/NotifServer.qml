pragma Singleton

import QtQuick
import Quickshell.Services.Notifications

/**
 * Singleton service providing a centralized interface for D-Bus notification signals.
 */
NotificationServer {
    id: notificationServer

    // Capabilities advertised to the system notification daemon
    bodySupported: true
    actionsSupported: true
    imageSupported: true
    persistenceSupported: true

    property bool trayOpen: false

    // notification history
    property ListModel history: ListModel {}

    function removeFromHistory(notifId) {
        for (var i = 0; i < history.count; i++) {
            if (history.get(i).notifId === notifId) {
                history.remove(i)
                return
            }
        }
    }

    /**
     * Primary handler for incoming notification requests.
     * Maps external system events to the internal shell state.
     */
    onNotification: notification => {
        // Enables automatic management within the trackedNotifications ObjectModel
        notification.tracked = true;
        if (!notification.hints["transient"]) {
            history.insert(0, {
                notifId: notification.id,
                appName: notification.appName,
                summary: notification.summary,
                body: notification.body,
                appIcon: notification.appIcon,
                urgency: notification.hints["urgency"] ?? 1,
                category: notification.hints["category"] ?? "",
                time: new Date()
            });
            // cap history length
            if (history.count > 50) history.remove(50);
        }
    }
}
