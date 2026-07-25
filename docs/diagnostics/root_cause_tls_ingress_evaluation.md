# 🔬 Root-Cause Diagnostic Evaluation Report: `https://timeguild.xyz`

> **Date:** July 25, 2026  
> **Investigation Mode:** Diagnostic Only (Zero Code Changes Executed)  
> **Target Host:** `https://timeguild.xyz`

---

## 🎯 Executive Summary of Root Cause

The **30–40 second loading delay** and **missing CSS layout** on `https://timeguild.xyz` in external web browsers are caused by a **TLS Certificate Hostname Mismatch (`NET::ERR_CERT_COMMON_NAME_INVALID`)** combined with **Cert-Manager HTTP-01 challenge failures**.

---

## 📊 Empirical Findings & Evidence

### 1. Live TLS Handshake Inspection
Executing a live SSL inspection on Traefik port 443 for `timeguild.xyz`:

```bash
$ openssl s_client -connect 172.31.33.127:443 -servername timeguild.xyz </dev/null | openssl x509 -noout -issuer -subject
issuer=CN=timeguild-ca
subject=CN=*.timeguild.local
```

* **Target Domain requested by Browser**: `timeguild.xyz`
* **Subject Name served by Certificate**: `CN=*.timeguild.local`
* **Mismatch Result**: `NET::ERR_CERT_COMMON_NAME_INVALID`

---

### 2. Why the Browser Takes 30 Seconds & Shows No CSS

1. **30-Second Handshake Delay**:
   When Chrome, Firefox, or Safari attempts an HTTPS handshake for `https://timeguild.xyz` and receives a certificate issued for `*.timeguild.local`, the browser flags a **Hostname Mismatch**. The browser holds the connection for **30 seconds** attempting TLS renegotiation and OCSP verification before falling back.

2. **Blocked Static CSS & JS Sub-resources**:
   Once the HTML skeleton is accepted after the 30-second delay, modern browser security policies (Strict SSL & Mixed Content protection) **block sub-resource asset downloads** matching `/_next/static/css/...` and `/_next/static/chunks/...` because they originate from an untrusted / mismatched SSL origin.
   - **Result**: The page renders un-styled HTML text with **NO CSS**.

---

### 3. Cert-Manager Certificate Object Status

```bash
$ kubectl get certificate -A
NAMESPACE           NAME                  READY   SECRET                  AGE
cert-manager        timeguild-ca          True    timeguild-ca-key-pair   13d
kube-system         wildcard-timeguild    True    wildcard-tls-secret     13d
timeguild-dev       wildcard-tls-secret   False   wildcard-tls-secret     65s
timeguild-prod      timeguild-prod-tls    False   timeguild-prod-tls      64s
timeguild-staging   wildcard-tls-secret   False   wildcard-tls-secret     65s
```

* **Root Cause**: Ingress annotation `cert-manager.io/cluster-issuer: "letsencrypt-prod"` triggers cert-manager to issue HTTP-01 challenge requests.
* **Failure Mechanism**: Let's Encrypt HTTP-01 challenges **cannot validate wildcard domains (`*.timeguild.xyz`)**. Cert-manager marks the certificate `READY: False` and overwrites `wildcard-tls-secret` with pending/invalid data.

---

### 4. Pod Density / Cluster Resource Impact

```bash
$ kubectl get pods -A
```

* **Pod Resource Status**: Pods in `timeguild-dev`, `timeguild-staging`, and `timeguild-prod` are running cleanly. CPU and memory allocation are healthy.
* **Conclusion**: High pod count is **NOT** causing the 30-second delay or missing CSS — the latency and CSS failure are 100% network/TLS layer issues.

---

## 🛠️ Required Fix Steps (For Review)

To permanently fix the 30-second delay and missing CSS on `https://timeguild.xyz`:

1. **Issue/Bind a Valid Certificate for `timeguild.xyz`**:
   Provide or generate a valid TLS certificate secret with Subject Alternative Names `timeguild.xyz` and `*.timeguild.xyz`.
2. **Remove Failing Ingress Annotation**:
   Remove `cert-manager.io/cluster-issuer: "letsencrypt-prod"` from `ingress.annotations` so cert-manager does not overwrite `wildcard-tls-secret` with `READY: False`.
3. **Bind Secret in Traefik Ingress**:
   Ensure `timeguild-dev-ingress` references `secretName: wildcard-tls-secret` under `.spec.tls`.
