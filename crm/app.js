/* ============================================================
   Customer Sales Data Practical — CRM App
   Pulls live data from Supabase csdp schema
   ============================================================ */

const SUPABASE_URL = 'https://nmemmfblpzrkwyljpmvp.supabase.co';
const SUPABASE_KEY = 'sb_publishable_Lc7rXKQ-1TJaQFu7a-nOVQ_5Sf3x__M';

async function query(table, params = '') {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}?${params}`, {
    headers: {
      'apikey': SUPABASE_KEY,
      'Authorization': `Bearer ${SUPABASE_KEY}`,
      'Accept-Profile': 'csdp'
    }
  });
  if (!res.ok) throw new Error(`${table}: ${res.status}`);
  return res.json();
}

async function loadDashboard() {
  try {
    // Hero stats
    const [customers, orders, deliveryRate, openOrders] = await Promise.all([
      query('customer', 'select=cust_id'),
      query('order', 'select=ord_id'),
      query('v_delivery_rate', 'select=*'),
      query('v_open_orders', 'select=*')
    ]);

    document.getElementById('stat-customers').textContent = customers.length;
    document.getElementById('stat-orders').textContent = orders.length;
    document.getElementById('stat-delivery-rate').textContent =
      deliveryRate[0]?.on_time_pct != null ? deliveryRate[0].on_time_pct + '%' : '—';
    document.getElementById('stat-open-orders').textContent = openOrders.length;

    // Customer count by type
    const custCount = await query('v_customer_count', 'select=*');
    const custCountEl = document.getElementById('data-customer-count');
    custCountEl.innerHTML = '';
    const ul = document.createElement('ul');
    ul.className = 'data-list';
    custCount.forEach(row => {
      const li = document.createElement('li');
      li.innerHTML = `<span>${row.cust_type}</span><span>${row.customer_count}</span>`;
      ul.appendChild(li);
    });
    custCountEl.appendChild(ul);

    // Open orders
    const openOrdersEl = document.getElementById('data-open-orders');
    if (openOrders.length === 0) {
      openOrdersEl.innerHTML = '<span class="badge badge-green">All orders delivered</span>';
    } else {
      openOrdersEl.innerHTML = `<div class="data-stat-big">${openOrders.length}</div><div class="data-stat-sub">Awaiting delivery</div>`;
    }

    // Delivery rate
    const dr = deliveryRate[0];
    document.getElementById('data-delivery-rate').innerHTML = dr
      ? `<div class="data-stat-big">${dr.on_time_pct}%</div>
         <div class="data-stat-sub">On-time</div>
         <ul class="data-list">
           <li><span>Total deliveries</span><span>${dr.total_deliveries}</span></li>
           <li><span>On time</span><span>${dr.on_time}</span></li>
           <li><span>Late</span><span>${dr.late}</span></li>
         </ul>`
      : 'No data';

    // Most profitable
    const profitable = await query('v_most_profitable_customers', 'select=*&order=net_revenue.desc&limit=5');
    const profEl = document.getElementById('data-profitable');
    profEl.innerHTML = '';
    const profList = document.createElement('ul');
    profList.className = 'data-list';
    profitable.forEach(row => {
      const li = document.createElement('li');
      li.innerHTML = `<span>${row.cust_name}</span><span>$${Number(row.net_revenue).toLocaleString()}</span>`;
      profList.appendChild(li);
    });
    profEl.appendChild(profList);

    // New customers
    const newCusts = await query('v_new_customers', 'select=*');
    const newEl = document.getElementById('data-new-customers');
    newEl.innerHTML = '';
    if (newCusts.length === 0) {
      newEl.textContent = 'No new customers on record.';
    } else {
      const newList = document.createElement('ul');
      newList.className = 'data-list';
      newCusts.forEach(row => {
        const li = document.createElement('li');
        li.innerHTML = `<span>${row.cust_name}</span><span class="badge badge-blue">${row.cust_type}</span>`;
        newList.appendChild(li);
      });
      newEl.appendChild(newList);
    }

    // Satisfaction
    const satisfaction = await query('v_customer_satisfaction', 'select=*');
    const satEl = document.getElementById('data-satisfaction');
    satEl.innerHTML = '';
    satisfaction.forEach(row => {
      const p = document.createElement('p');
      p.style.cssText = 'font-size:var(--text-xs);margin-bottom:var(--space-3);padding-bottom:var(--space-3);border-bottom:1px solid var(--color-divider);';
      p.innerHTML = `<strong style="color:var(--color-text);display:block;margin-bottom:2px;">${row.cust_name}</strong>${row.cust_response}`;
      satEl.appendChild(p);
    });

    // Customer table
    const allCustomers = await query('customer', 'select=*&order=cust_id.asc');
    const tbody = document.getElementById('customer-table-body');
    tbody.innerHTML = '';
    allCustomers.forEach(c => {
      const tr = document.createElement('tr');
      tr.innerHTML = `<td>${c.cust_id}</td><td>${c.cust_name}</td><td>${c.cust_type}</td><td>${c.cust_branch || '—'}</td>`;
      tbody.appendChild(tr);
    });

  } catch (err) {
    console.error('Dashboard load error:', err);
  }
}

// Theme toggle
(function(){
  const t = document.querySelector('[data-theme-toggle]');
  const r = document.documentElement;
  let d = (localStorage && localStorage.getItem('theme')) || (matchMedia('(prefers-color-scheme:dark)').matches ? 'dark' : 'light');
  r.setAttribute('data-theme', d);
  function setIcon() {
    if (!t) return;
    t.innerHTML = d === 'dark'
      ? '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="5"/><path d="M12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M1 12h2M21 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42"/></svg>'
      : '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/></svg>';
    t.setAttribute('aria-label', 'Switch to ' + (d === 'dark' ? 'light' : 'dark') + ' mode');
    if (localStorage) localStorage.setItem('theme', d);
  }
  setIcon();
  if (t) t.addEventListener('click', () => { d = d === 'dark' ? 'light' : 'dark'; r.setAttribute('data-theme', d); setIcon(); });
})();

// Scroll reveal
(function(){
  const els = document.querySelectorAll('.reveal');
  const obs = new IntersectionObserver((entries) => {
    entries.forEach(e => { if (e.isIntersecting) { e.target.classList.add('visible'); obs.unobserve(e.target); } });
  }, { threshold: .12, rootMargin: '0px 0px -40px 0px' });
  els.forEach(el => obs.observe(el));
})();

// Init
document.addEventListener('DOMContentLoaded', loadDashboard);
