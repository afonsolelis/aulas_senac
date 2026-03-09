const fs = require('fs');
const path = require('path');
const https = require('https');
const fetch = require('node-fetch');
const { JSDOM } = require('jsdom');
const { Polly } = require('@pollyjs/core');
const NodeHttpAdapter = require('@pollyjs/adapter-node-http');
const FSPersister = require('@pollyjs/persister-fs');

Polly.register(NodeHttpAdapter);
Polly.register(FSPersister);

const ROOT = path.resolve(__dirname, '..');
const CASSETTES_DIR = path.join(__dirname, 'cassettes');
const LOGO_URL = 'https://res.cloudinary.com/dyhjjms8y/image/upload/v1759512534/logo-SENAC_k3d68v.png';
const LINKEDIN_URL = 'https://www.linkedin.com/in/afonsolelis/';

function loadHTML(filePath) {
  const html = fs.readFileSync(path.join(ROOT, filePath), 'utf-8');
  const dom = new JSDOM(html);
  return dom.window.document;
}

function createPolly(cassetteName) {
  return new Polly(cassetteName, {
    adapters: ['node-http'],
    persister: 'fs',
    persisterOptions: {
      fs: { recordingsDir: CASSETTES_DIR },
    },
    recordIfMissing: true,
    expiresIn: '1d',
    expiryStrategy: 'record',
    matchRequestsBy: {
      method: true,
      url: true,
      headers: false,
      body: false,
    },
  });
}

function rawHttpGet(url) {
  return new Promise((resolve) => {
    https.get(url, (res) => {
      res.resume();
      resolve(res.statusCode);
    }).on('error', () => resolve(0));
  });
}

describe('index.html - Logo do Senac', () => {
  let polly;

  beforeAll(() => {
    polly = createPolly('senac-logo');
  });

  afterAll(async () => {
    await polly.stop();
  });

  test('URL do logo retorna status 200', async () => {
    const response = await fetch(LOGO_URL);

    expect(response.status).toBe(200);
  });

  test('URL do logo retorna Content-Type de imagem', async () => {
    const response = await fetch(LOGO_URL);
    const contentType = response.headers.get('content-type');

    expect(contentType).toMatch(/^image\//);
  });
});

describe('professor.html - LinkedIn', () => {
  test('link do LinkedIn presente no HTML com formato válido', () => {
    const doc = loadHTML('pages/professor.html');
    const allLinks = Array.from(doc.querySelectorAll('a[href]'));
    const linkedinLink = allLinks.find(l => l.getAttribute('href').includes('linkedin.com'));
    const href = linkedinLink?.getAttribute('href');

    expect(linkedinLink).toBeDefined();
    expect(href).toMatch(/^https:\/\/www\.linkedin\.com\/in\/.+/);
  });

  test('servidor do LinkedIn responde (link não está quebrado)', async () => {
    const status = await rawHttpGet(LINKEDIN_URL);

    expect(status).not.toBe(0);
    expect(status).not.toBe(404);
  });
});
