(function () {
  "use strict";

  var config = window.SANTA_CONFIG || {};
  var apiUrl = (config.supabaseUrl || "").replace(/\/$/, "");
  var apiKey = config.supabaseAnonKey || "";
  var page = document.body.getAttribute("data-page");
  var drawerStorageKey = "santa-drawer-id";
  var completedStorageKey = "santa-draw-completed";
  var pendingStorageKey = "santa-pending-keyword";
  var submissionStorageKey = "santa-music-submitted";

  function ready() {
    return apiUrl.indexOf("https://") === 0 && apiKey && apiKey !== "YOUR_SUPABASE_ANON_KEY";
  }

  function request(path, options) {
    if (!ready()) {
      return Promise.reject(new Error("La connexion à la base n’est pas configurée."));
    }
    var headers = {
      apikey: apiKey,
      Authorization: "Bearer " + apiKey,
      "Content-Type": "application/json"
    };
    var requestOptions = options || {};
    requestOptions.headers = Object.assign(headers, requestOptions.headers || {});
    return fetch(apiUrl + "/rest/v1/" + path, requestOptions).then(function (response) {
      if (!response.ok) {
        return response.text().then(function (message) {
          throw new Error(message || "La requête a échoué.");
        });
      }
      return response.text().then(function (body) {
        return body ? JSON.parse(body) : null;
      });
    });
  }

  function drawerId() {
    var id = window.localStorage.getItem(drawerStorageKey);
    if (!id) {
      id = window.crypto && window.crypto.randomUUID
        ? window.crypto.randomUUID()
        : "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, function (char) {
          var random = Math.random() * 16 | 0;
          return (char === "x" ? random : random & 3 | 8).toString(16);
        });
      window.localStorage.setItem(drawerStorageKey, id);
    }
    return id;
  }

  function showStatus(element, message, isError) {
    element.textContent = message;
    element.className = isError ? "status error" : "status";
  }

  function errorMessage(error) {
    try {
      var details = JSON.parse(error.message);
      if (details.code === "PGRST202") {
        return "Le schéma Supabase n’est pas à jour. Exécutez supabase.sql dans le SQL Editor, puis rechargez le site.";
      }
      if (details.message) return details.message;
    } catch (parseError) {
      return error.message;
    }
    return error.message;
  }

  function submitPage() {
    var form = document.getElementById("submit-form");
    var input = document.getElementById("keyword");
    var status = document.getElementById("submit-status");
    var button = form.querySelector("button[type=submit]");
    var submissionsOpen = false;

    if (window.localStorage.getItem(submissionStorageKey) === "true") {
      button.disabled = true;
      showStatus(status, "Une musique a déjà été déposée depuis ce navigateur.");
    } else {
      button.disabled = true;
      showStatus(status, "Vérification de l’ouverture des participations…");
    }

    request("rpc/submissions_are_open", {
      method: "POST",
      body: "{}"
    }).then(function (isOpen) {
      submissionsOpen = isOpen === true;
      var alreadySubmitted = window.localStorage.getItem(submissionStorageKey) === "true";
      button.disabled = alreadySubmitted || !submissionsOpen;
      if (alreadySubmitted) {
        showStatus(status, "Une musique a déjà été déposée depuis ce navigateur.");
      } else if (!submissionsOpen) {
        showStatus(status, "Les participations sont fermées.");
      } else {
        showStatus(status, "");
      }
    }).catch(function (error) {
      button.disabled = true;
      showStatus(status, errorMessage(error), true);
    });

    form.addEventListener("submit", function (event) {
      event.preventDefault();
      if (window.localStorage.getItem(submissionStorageKey) === "true") {
        button.disabled = true;
        showStatus(status, "Une musique a déjà été déposée depuis ce navigateur.");
        return;
      }
      if (!submissionsOpen) {
        button.disabled = true;
        showStatus(status, "Les participations sont fermées.", true);
        return;
      }
      var text = input.value.trim();
      if (!text) {
        showStatus(status, "Renseignez une musique avant de la déposer.", true);
        return;
      }
      button.disabled = true;
      showStatus(status, "Enregistrement en cours…");
      request("keywords", {
        method: "POST",
        headers: { Prefer: "return=minimal" },
        body: JSON.stringify({ text: text })
      }).then(function () {
        window.localStorage.setItem(submissionStorageKey, "true");
        input.value = "";
        showStatus(status, "Votre musique a bien été déposée. Merci !");
      }).catch(function (error) {
        showStatus(status, errorMessage(error), true);
      }).then(function () {
        button.disabled = window.localStorage.getItem(submissionStorageKey) === "true" || !submissionsOpen;
      });
    });
  }

  function drawPage() {
    var result = document.getElementById("draw-result");
    var status = document.getElementById("draw-status");
    var drawButton = document.getElementById("draw-again");
    var confirmButton = document.getElementById("confirm-draw");
    var storedPending = window.localStorage.getItem(pendingStorageKey);
    var pending = storedPending ? JSON.parse(storedPending) : null;
    var pendingId = pending ? pending.id : null;
    var busy = false;
    var drawOpen = false;
    var complete = false;

    function setBusy(value) {
      busy = value;
      drawButton.disabled = value || complete || !drawOpen;
      confirmButton.disabled = value || !pendingId;
    }

    function markComplete() {
      complete = true;
      window.localStorage.setItem(completedStorageKey, "true");
      window.localStorage.removeItem(pendingStorageKey);
      pendingId = null;
      result.textContent = "Tirage effectué ! Maintenant il faut identifier à qui elle appartient...";
      showStatus(status, "Ce tirage est terminé sur cet appareil.");
      drawButton.disabled = true;
      drawButton.textContent = "Tirage terminé";
      confirmButton.disabled = true;
      confirmButton.hidden = true;
    }

    if (window.localStorage.getItem(completedStorageKey) === "true") {
      markComplete();
      return;
    }

    showStatus(status, "Vérification de l’ouverture du tirage…");
    request("rpc/draw_is_open", {
      method: "POST",
      body: "{}"
    }).then(function (isOpen) {
      if (isOpen !== true) {
        result.textContent = "Le tirage n’est pas encore ouvert.";
        showStatus(status, "Le tirage sera révélé quand tout le monde aura participé.");
        return;
      }
      drawOpen = true;
      result.textContent = pending ? pending.text : "Prêt quand vous l’êtes.";
      showStatus(status, pending
        ? "Musique provisoire. Vous pouvez relancer ou la valider."
        : "La musique ne sera retirée qu’après validation.");
      setBusy(false);
    }).catch(function (error) {
      result.textContent = "Le tirage n’est pas disponible.";
      showStatus(status, errorMessage(error), true);
    });

    drawButton.addEventListener("click", function () {
      if (busy || !drawOpen) return;
      setBusy(true);
      result.textContent = "La roulette tourne…";
      showStatus(status, "Recherche d’une musique disponible…");
      request("rpc/draw_keyword", {
        method: "POST",
        body: JSON.stringify({
          p_drawer_id: drawerId(),
          p_previous_keyword_id: pendingId
        })
      }).then(function (rows) {
        if (rows && rows[0] && rows[0].already_completed) {
          markComplete();
          return;
        }
        if (!rows || !rows.length) {
          pendingId = null;
          pending = null;
          window.localStorage.removeItem(pendingStorageKey);
          result.textContent = "Aucune musique disponible.";
          showStatus(status, "Aucune musique n’est disponible pour le moment.");
          return;
        }
        pendingId = rows[0].keyword_id;
        pending = { id: pendingId, text: rows[0].keyword_text };
        window.localStorage.setItem(pendingStorageKey, JSON.stringify(pending));
        result.textContent = rows[0].keyword_text;
        showStatus(status, "Musique provisoire. Vous pouvez relancer ou la valider.");
      }).catch(function (error) {
        showStatus(status, errorMessage(error), true);
        result.textContent = "Le tirage n’a pas pu démarrer.";
      }).then(function () {
        setBusy(false);
      });
    });

    confirmButton.addEventListener("click", function () {
      if (busy || !pendingId) return;
      setBusy(true);
      showStatus(status, "Validation en cours…");
      request("rpc/confirm_keyword", {
        method: "POST",
        body: JSON.stringify({
          p_drawer_id: drawerId(),
          p_keyword_id: pendingId
        })
      }).then(function (confirmed) {
        if (confirmed !== true) {
          pendingId = null;
          pending = null;
          window.localStorage.removeItem(pendingStorageKey);
          result.textContent = "Cette musique n’est plus disponible.";
          showStatus(status, "Relancez le tirage pour en choisir un autre.", true);
          return;
        }
        markComplete();
      }).catch(function (error) {
        showStatus(status, errorMessage(error), true);
      }).then(function () {
        setBusy(false);
      });
    });
  }

  if (page === "submit") submitPage();
  if (page === "draw") drawPage();
}());