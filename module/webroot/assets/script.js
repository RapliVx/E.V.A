import { exec as ksuExec, toast, listPackages, getPackagesInfo } from 'https://esm.run/kernelsu';

async function exec(command) {
  const { errno, stdout, stderr } = await ksuExec(command);
  if (errno !== 0 && !stdout) throw new Error(stderr || `Exit ${errno}`);
  return stdout.trim();
}

async function getSysctl(node) {
  try { 
    return await exec(`sysctl -n ${node} 2>/dev/null`); 
  } catch (e) { 
    return null; 
  }
}

window.updateSysctl = async function(node, value) {
  try {
    await exec(`sysctl -w ${node}=${value}`);
    toast(`Set ${node} = ${value}`);
    setTimeout(refreshStats, 500); 
  } catch (e) { toast(`Gagal mengubah ${node}`); }
};

function linkSlider(sliderId, valId) {
  const slider = document.getElementById(sliderId);
  const valText = document.getElementById(valId);
  if(slider && valText) {
    slider.addEventListener('input', () => valText.innerText = slider.value);
  }
}

async function checkEvaSupport() {
  const isSupported = await getSysctl('kernel.sched_eva_enable');
  if (isSupported === null || isSupported === "") {
    toast("FATAL: E.V.A tidak ditemukan di kernel ini!");
    document.getElementById('switch-enable').disabled = true;
    return false;
  }
  return true;
}

async function loadEvaConfig() {
  if (!(await checkEvaSupport())) return;

  const [enable, smartMode, nice, freq, heavy, light, poll] = await Promise.all([
    getSysctl('kernel.sched_eva_enable'),
    getSysctl('kernel.sched_eva_smart_mode'),
    getSysctl('kernel.sched_eva_nice'),
    getSysctl('kernel.sched_eva_throttle_freq'),
    getSysctl('kernel.sched_eva_heavy_util'),
    getSysctl('kernel.sched_eva_light_util'),
    getSysctl('kernel.sched_eva_poll_ms')
  ]);

  if(enable) document.getElementById('switch-enable').selected = (enable === '1');
  if(smartMode) document.getElementById('select-smart-mode').value = smartMode;
  if(nice) { document.getElementById('slider-nice').value = nice; document.getElementById('val-nice').innerText = nice; }
  if(freq) { document.getElementById('slider-freq').value = freq; document.getElementById('val-freq').innerText = freq; }
  if(heavy) { document.getElementById('slider-heavy').value = heavy; document.getElementById('val-heavy').innerText = heavy; }
  if(light) { document.getElementById('slider-light').value = light; document.getElementById('val-light').innerText = light; }
  if(poll) { document.getElementById('slider-poll').value = poll; document.getElementById('val-poll').innerText = poll; }
  
  refreshStats();
}

window.refreshStats = async function() {
  const statusPill = document.getElementById('status-indicator');
  const pidPill = document.getElementById('pid-indicator');
  
  try {
    const pid = await getSysctl('kernel.sched_eva_pid');
    
    if (pid && pid !== "0" && pid !== "") {
      statusPill.innerText = 'ACTIVE';
      statusPill.style.color = '';
      statusPill.style.borderColor = '';
      
      pidPill.innerText = `PID: ${pid}`;
      pidPill.style.background = 'var(--md-sys-color-primary-container)';
      pidPill.style.color = 'var(--md-sys-color-on-primary-container)';
    } else {
      statusPill.innerText = 'STANDBY';
      pidPill.innerText = `PID: NULL`;
      pidPill.style.background = 'var(--md-sys-color-secondary-container)';
      pidPill.style.color = 'var(--md-sys-color-on-secondary-container)';
    }
  } catch (e) { 
      console.error("Gagal memuat statistik banner."); 
  }
};

window.injectPID = async function(pkgName) {
  try {
    const pids = await exec(`pidof ${pkgName} || echo ""`);
    if (!pids || pids.trim() === "") {
      toast(`${pkgName} tidak berjalan! Buka gamenya dahulu.`);
      return;
    }
    const targetPid = pids.trim().split(/\s+/)[0];
    await updateSysctl('kernel.sched_eva_pid', targetPid);
    toast(`Injected PID: ${targetPid}`);
  } catch (e) { toast(`Error sistem: ${pkgName}`); }
};

window.killEvaPID = async function() {
  await updateSysctl('kernel.sched_eva_pid', '0');
  toast("Target di-reset.");
};

window.toggleBoost = async function(pkgName, enable) {
  try {
    if (enable) {
      await exec(`echo "${pkgName}" >> /data/adb/modules/evamgr/PackageList.txt`);
      toast(`Enabled auto-boost for ${pkgName}`);
    } else {
      await exec(`sed -i '/^${pkgName}$/d' /data/adb/modules/evamgr/PackageList.txt`);
      toast(`Disabled auto-boost for ${pkgName}`);
    }
  } catch (e) {
    toast(`Gagal mengubah setelan untuk ${pkgName}`);
  }
};

async function loadAppList() {
  const container = document.getElementById("app-list-container");
  try {
    const [userPkgsList, pmListOut, pListOut] = await Promise.all([
      listPackages('user'),
      exec("pm list packages -3 2>/dev/null || true"),
      exec("cat /data/adb/modules/evamgr/PackageList.txt 2>/dev/null || true")
    ]);

    let fullInfo = [];
    if (userPkgsList && userPkgsList.length > 0) {
      fullInfo = await getPackagesInfo(userPkgsList);
    }

    let thirdPartyPkgs = new Set();
    if (pmListOut) {
        pmListOut.split("\n").forEach(e => {
            const pkg = e.replace("package:", "").trim();
            if (pkg) thirdPartyPkgs.add(pkg);
        });
    }

    let enabledPkgs = new Set();
    if (pListOut) {
        pListOut.split("\n").forEach(e => {
            const pkg = e.trim();
            if (pkg && !pkg.startsWith('#')) enabledPkgs.add(pkg);
        });
    }
    
    let targetApps = fullInfo.filter(pkg => thirdPartyPkgs.has(pkg.packageName));
    targetApps.sort((a, b) => (a.appLabel || a.packageName).localeCompare(b.appLabel || b.packageName));

    const fragment = document.createDocumentFragment();
    
    targetApps.forEach(pkg => {
      const appName = pkg.appLabel || pkg.packageName;
      const isEnabled = enabledPkgs.has(pkg.packageName);
      const label = document.createElement('label');
      
      label.style.cssText = `
        display: flex; align-items: center; justify-content: space-between; 
        padding: 12px 16px; background: var(--md-sys-color-surface-container); 
        border-radius: 24px; margin-bottom: 8px; cursor: pointer; 
        position: relative; overflow: hidden; border: 1px solid var(--md-sys-color-outline-variant);
        transition: transform 0.2s, background-color 0.2s;
      `;
      
      label.innerHTML = `
        <md-ripple></md-ripple>
        <div style="display: flex; align-items: center; gap: 16px; flex: 1; min-width: 0; pointer-events: none; z-index: 1;">
          <div style="width: 48px; height: 48px; border-radius: 12px; overflow: hidden; display: flex; align-items: center; justify-content: center; background: var(--md-sys-color-surface-variant); flex-shrink: 0;">
            <img loading="lazy" src="ksu://icon/${pkg.packageName}" style="width: 100%; height: 100%; object-fit: cover;" onerror="this.style.display='none'; this.nextElementSibling.style.display='block';">
            <md-icon style="display: none; color: var(--md-sys-color-on-surface-variant);">android</md-icon>
          </div>
          <div style="display: flex; flex-direction: column; overflow: hidden;">
            <span style="font-size: 16px; font-weight: 600; color: var(--md-sys-color-on-surface); white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${appName}</span>
            <span style="font-size: 12px; color: var(--md-sys-color-on-surface-variant); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; margin-top: 2px;">${pkg.packageName}</span>
          </div>
        </div>
        <md-switch icons style="z-index: 1; flex-shrink: 0; margin-left: 12px; --md-switch-selected-track-color: var(--md-sys-color-primary); --md-switch-selected-hover-track-color: var(--md-sys-color-primary); --md-switch-selected-focus-track-color: var(--md-sys-color-primary); --md-switch-selected-pressed-track-color: var(--md-sys-color-primary);" ${isEnabled ? 'selected' : ''}></md-switch>
      `;

      const switchEl = label.querySelector('md-switch');
      switchEl.addEventListener('change', (e) => {
        toggleBoost(pkg.packageName, e.target.selected);
      });

      fragment.appendChild(label);
    });

    container.innerHTML = '';
    container.appendChild(fragment);

  } catch (e) {
    container.innerHTML = `<div style="padding: 16px; color: var(--md-sys-color-error);">Gagal memuat aplikasi</div>`;
  }
}

document.addEventListener('DOMContentLoaded', () => {
  linkSlider('slider-nice', 'val-nice');
  linkSlider('slider-freq', 'val-freq');
  linkSlider('slider-heavy', 'val-heavy');
  linkSlider('slider-light', 'val-light');
  linkSlider('slider-poll', 'val-poll');

  const navItems = document.querySelectorAll('.nav-item');
  const wrapper = document.getElementById('views-wrapper');
  
  navItems.forEach(item => {
    item.addEventListener('click', () => {
      const index = item.getAttribute('data-index');
      navItems.forEach(n => n.classList.remove('active'));
      item.classList.add('active');
      wrapper.style.transform = `translateX(-${index * (100 / 4)}%)`;
    });
  });

  setTimeout(() => {
    document.body.classList.add('loaded');
    loadEvaConfig();
    loadAppList();
    setInterval(refreshStats, 3000);
  }, 500);
});