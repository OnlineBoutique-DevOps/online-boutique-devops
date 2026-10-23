// Copyright 2026 Online Boutique — login/registro de compradores y reseñas
// verificadas por compra. Toda la lógica vive en el reviewservice (REST);
// aquí solo se hace el puente HTTP y las cookies de sesión.

package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"time"

	"github.com/gorilla/mux"
	"github.com/sirupsen/logrus"
)

const userCookieName = "boutique_user"

var reviewHTTP = &http.Client{Timeout: 5 * time.Second}

type reviewUser struct {
	ID    int    `json:"id"`
	Email string `json:"email"`
	Name  string `json:"name"`
}

type reviewEntry struct {
	ID        int    `json:"id"`
	Rating    int    `json:"rating"`
	Comment   string `json:"comment"`
	Author    string `json:"author"`
	CreatedAt string `json:"created_at"`
}

// reviewAPI llama al reviewservice. token puede ir vacío.
func (fe *frontendServer) reviewAPI(ctx context.Context, method, path, token string, body interface{}) (int, []byte, error) {
	var rd io.Reader
	if body != nil {
		b, err := json.Marshal(body)
		if err != nil {
			return 0, nil, err
		}
		rd = bytes.NewReader(b)
	}
	req, err := http.NewRequestWithContext(ctx, method, "http://"+fe.reviewSvcAddr+path, rd)
	if err != nil {
		return 0, nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	resp, err := reviewHTTP.Do(req)
	if err != nil {
		return 0, nil, err
	}
	defer resp.Body.Close()
	data, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	return resp.StatusCode, data, nil
}

// userToken saca el token de sesión de comprador de la cookie.
func userToken(r *http.Request) string {
	c, err := r.Cookie(userCookieName)
	if err != nil {
		return ""
	}
	return c.Value
}

// currentUser consulta /api/me; nil si no hay sesión válida.
func (fe *frontendServer) currentUser(r *http.Request) *reviewUser {
	tok := userToken(r)
	if tok == "" {
		return nil
	}
	code, body, err := fe.reviewAPI(r.Context(), http.MethodGet, "/api/me", tok, nil)
	if err != nil || code != http.StatusOK {
		return nil
	}
	var out struct {
		User reviewUser `json:"user"`
	}
	if json.Unmarshal(body, &out) != nil {
		return nil
	}
	return &out.User
}

func setUserCookie(w http.ResponseWriter, token string) {
	http.SetCookie(w, &http.Cookie{
		Name:     userCookieName,
		Value:    token,
		Path:     "/",
		HttpOnly: true,
		MaxAge:   24 * 3600,
	})
}

func clearUserCookie(w http.ResponseWriter) {
	http.SetCookie(w, &http.Cookie{
		Name: userCookieName, Value: "", Path: "/", MaxAge: -1, HttpOnly: true,
	})
}

// ---------- páginas ----------

func (fe *frontendServer) loginPageHandler(w http.ResponseWriter, r *http.Request) {
	log := r.Context().Value(ctxKeyLog{}).(logrus.FieldLogger)
	if err := templates.ExecuteTemplate(w, "login", fe.injectCommonTemplateData(r, map[string]interface{}{
		"show_currency": false,
		"next":          r.URL.Query().Get("next"),
		"error":         r.URL.Query().Get("error"),
	})); err != nil {
		log.Println(err)
	}
}

func (fe *frontendServer) registerPageHandler(w http.ResponseWriter, r *http.Request) {
	log := r.Context().Value(ctxKeyLog{}).(logrus.FieldLogger)
	if err := templates.ExecuteTemplate(w, "register", fe.injectCommonTemplateData(r, map[string]interface{}{
		"show_currency": false,
		"error":         r.URL.Query().Get("error"),
	})); err != nil {
		log.Println(err)
	}
}

func (fe *frontendServer) registerSubmitHandler(w http.ResponseWriter, r *http.Request) {
	log := r.Context().Value(ctxKeyLog{}).(logrus.FieldLogger)
	code, body, err := fe.reviewAPI(r.Context(), http.MethodPost, "/api/register", "", map[string]string{
		"email":    r.FormValue("email"),
		"password": r.FormValue("password"),
		"name":     r.FormValue("name"),
	})
	if err != nil || code != http.StatusCreated {
		var e struct {
			Error string `json:"error"`
		}
		json.Unmarshal(body, &e)
		msg := e.Error
		if msg == "" {
			msg = "no se pudo registrar, intenta de nuevo"
		}
		http.Redirect(w, r, baseUrl+"/register?error="+url.QueryEscape(msg), http.StatusFound)
		return
	}
	var out struct {
		Token string `json:"token"`
	}
	if json.Unmarshal(body, &out) != nil || out.Token == "" {
		renderHTTPError(log, fe, r, w, fmt.Errorf("register: respuesta inesperada"), http.StatusInternalServerError)
		return
	}
	setUserCookie(w, out.Token)
	http.Redirect(w, r, baseUrl+"/", http.StatusFound)
}

func (fe *frontendServer) loginSubmitHandler(w http.ResponseWriter, r *http.Request) {
	next := r.FormValue("next")
	if next == "" {
		next = baseUrl + "/"
	}
	code, body, err := fe.reviewAPI(r.Context(), http.MethodPost, "/api/login", "", map[string]string{
		"email":    r.FormValue("email"),
		"password": r.FormValue("password"),
	})
	if err != nil || code != http.StatusOK {
		var e struct {
			Error string `json:"error"`
		}
		json.Unmarshal(body, &e)
		msg := e.Error
		if msg == "" {
			msg = "credenciales invalidas"
		}
		http.Redirect(w, r, baseUrl+"/login?error="+url.QueryEscape(msg)+"&next="+url.QueryEscape(next), http.StatusFound)
		return
	}
	var out struct {
		Token string `json:"token"`
	}
	if json.Unmarshal(body, &out) != nil || out.Token == "" {
		http.Redirect(w, r, baseUrl+"/login?error="+url.QueryEscape("error de sesion"), http.StatusFound)
		return
	}
	setUserCookie(w, out.Token)
	http.Redirect(w, r, next, http.StatusFound)
}

// submitReviewHandler — POST /product/{id}/review
func (fe *frontendServer) submitReviewHandler(w http.ResponseWriter, r *http.Request) {
	log := r.Context().Value(ctxKeyLog{}).(logrus.FieldLogger)
	id := mux.Vars(r)["id"]
	tok := userToken(r)
	productURL := baseUrl + "/product/" + id

	if tok == "" {
		http.Redirect(w, r, baseUrl+"/login?next="+url.QueryEscape(productURL), http.StatusFound)
		return
	}
	rating, _ := strconv.Atoi(r.FormValue("rating"))
	code, body, err := fe.reviewAPI(r.Context(), http.MethodPost, "/api/reviews", tok, map[string]interface{}{
		"product_id": id,
		"rating":     rating,
		"comment":    r.FormValue("comment"),
	})
	if err != nil || code != http.StatusCreated {
		var e struct {
			Error string `json:"error"`
		}
		json.Unmarshal(body, &e)
		log.WithField("product", id).WithField("status", code).Warnf("review rechazada: %s", e.Error)
		// redirige al producto con el motivo visible
		http.Redirect(w, r, productURL+"?review_error="+url.QueryEscape(firstNonEmpty(e.Error, "no se pudo publicar la resena")), http.StatusFound)
		return
	}
	http.Redirect(w, r, productURL+"#reviews", http.StatusFound)
}

func firstNonEmpty(vals ...string) string {
	for _, v := range vals {
		if v != "" {
			return v
		}
	}
	return ""
}

// recordPurchase — registra en reviewservice los productos comprados.
func (fe *frontendServer) recordPurchase(ctx context.Context, r *http.Request, orderID string, productIDs []string) {
	tok := userToken(r)
	if tok == "" {
		return
	}
	code, body, err := fe.reviewAPI(ctx, http.MethodPost, "/api/purchases", tok, map[string]interface{}{
		"order_id":    orderID,
		"product_ids": productIDs,
	})
	if err != nil || code != http.StatusCreated {
		r.Context().Value(ctxKeyLog{}).(logrus.FieldLogger).
			Warnf("no se registro la compra para reseñas (code=%d, err=%v, body=%s)", code, err, body)
	}
}
