use std::collections::HashSet;
use std::fs::{self, File};
use std::io::Read;
use std::path::Path;
use std::thread;
use std::time::{Duration, SystemTime};
use std::process::Command;

const SCHED_EVA_PID_FILE: &str = "/proc/sys/kernel/sched_eva_pid";

struct AppCache {
    packages: HashSet<String>,
    last_modified: SystemTime,
}

impl AppCache {
    fn new() -> Self {
        Self {
            packages: HashSet::new(),
            last_modified: SystemTime::UNIX_EPOCH,
        }
    }

    fn update_if_needed(&mut self, path: &str) {
        if let Ok(metadata) = fs::metadata(path) {
            if let Ok(mtime) = metadata.modified() {
                if mtime > self.last_modified {
                    self.packages.clear();
                    if let Ok(contents) = fs::read_to_string(path) {
                        for line in contents.lines() {
                            let pkg = line.trim();
                            if !pkg.is_empty() && !pkg.starts_with('#') {
                                self.packages.insert(pkg.to_string());
                            }
                        }
                    }
                    self.last_modified = mtime;
                }
            }
        }
    }
}

fn get_active_pids_dumpsys(pids: &mut Vec<u32>) {
    pids.clear();
    if let Ok(output) = Command::new("dumpsys").arg("window").output() {
        if let Ok(out_str) = std::str::from_utf8(&output.stdout) {
            for line in out_str.lines() {
                if line.contains("Session Session{") {
                    if let Some(uid_pid) = line.split_whitespace().nth(2) {
                        if let Some(pid_str) = uid_pid.split(':').next() {
                            if let Ok(pid) = pid_str.parse::<u32>() {
                                pids.push(pid);
                            }
                        }
                    }
                }
            }
        }
    }
}

fn get_package_name_from_pid(pid: u32, buf: &mut String) -> bool {
    buf.clear();
    let cmdline_path = format!("/proc/{}/cmdline", pid);
    if let Ok(mut file) = File::open(&cmdline_path) {
        if file.read_to_string(buf).is_ok() {
            if let Some(first) = buf.split('\0').next() {
                let pkg_len = first.len();
                buf.truncate(pkg_len);
                return true;
            }
        }
    }
    false
}

fn write_eva_pid(pid: u32) -> bool {
    match fs::write(SCHED_EVA_PID_FILE, pid.to_string()) {
        Ok(_) => true,
        Err(_) => false,
    }
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let package_list_path = if args.len() > 1 {
        args[1].clone()
    } else {
        "/data/adb/modules/evamgr/PackageList.txt".to_string()
    };

    println!("E.V.A Daemon Starting...");
    println!("Package list path: {}", package_list_path);

    let mut current_eva_pid = 0;
    let mut cache = AppCache::new();
    let mut top_pids = Vec::with_capacity(32);
    let mut cmdline_buf = String::with_capacity(256);

    loop {
        cache.update_if_needed(&package_list_path);
        
        let mut found_pid = 0;

        if !cache.packages.is_empty() {
            get_active_pids_dumpsys(&mut top_pids);
            
            for &pid in &top_pids {
                if get_package_name_from_pid(pid, &mut cmdline_buf) {
                    let pkg_name = cmdline_buf.trim();
                    if cache.packages.contains(pkg_name) {
                        found_pid = pid;
                        break;
                    }
                }
            }
        }

        if found_pid != current_eva_pid {
            if write_eva_pid(found_pid) {
                if found_pid > 0 {
                    println!("[+] Game detected! Set sched_eva_pid -> {}", found_pid);
                } else {
                    println!("[-] Game minimized/closed. Set sched_eva_pid -> 0");
                }
                current_eva_pid = found_pid;
            }
        }

        thread::sleep(Duration::from_secs(2));
    }
}
