# ---
# Module: WeChat X11 Clipboard Bridge
# Description: 用 xwayclip 在微信的 XWayland 剪贴板与 Wayland 会话剪贴板之间双向同步
# Scope: Home Manager
# Notes:
# - 微信 4.x 的 launcher 硬编码 QT_QPA_PLATFORM=xcb，且闭包内没有 qtwayland 平台插件，
#   无法改为原生 Wayland，因此只能靠外部桥接。
# - xwayclip 通过 XFixes 与 ext/wlr-data-control 做全量快照同步，并用内容指纹抑制
#   双协议回声，替代了此前基于 1 秒轮询的自研实现。
# - 桥接范围是整会话剪贴板，不局限微信窗口；这是 xwayclip 的既有权衡。
# ---

{ pkgs, inputs, ... }:

let
  xwayclipPatch = pkgs.writeText "xwayclip-patch.py" ''
    import pathlib

    def patch(rel_path: str, old: str, new: str) -> None:
        path = pathlib.Path(rel_path)
        text = path.read_text(encoding="utf-8")
        if old not in text:
            raise RuntimeError(f"Patch target not found in {rel_path}")
        path.write_text(text.replace(old, new, 1), encoding="utf-8")

    patch(
        "src/snapshot.rs",
        """\
        pub fn new(mut offers: Vec<Offer>) -> Self {
            offers.sort_by(|left, right| left.mime_type.cmp(&right.mime_type));
            offers.dedup_by(|left, right| left.mime_type == right.mime_type);

            Self { offers }
        }""",
        """\
        pub fn new(mut offers: Vec<Offer>) -> Self {
            offers.retain(|offer| !offer.data.is_empty());
            offers.sort_by(|left, right| left.mime_type.cmp(&right.mime_type));
            offers.dedup_by(|left, right| left.mime_type == right.mime_type);

            Self { offers }
        }

        pub fn x11_fingerprint(&self) -> Hash {
            fingerprint(
                self.x11_targets()
                    .into_iter()
                    .map(|(mime_type, index)| (mime_type, self.offers[index].data.as_slice())),
            )
        }""",
    )

    patch(
        "src/lib.rs",
        """\
            ClipboardUpdate::Cleared => {
                if *x11_state == ClipboardState::Cleared {
                    return Ok(());
                }
                *x11_state = ClipboardState::Cleared;

                wayland::clear_clipboard().context("failed to clear the Wayland clipboard")?;
                *wayland_state = ClipboardState::Cleared;
                info!("cleared Wayland clipboard from X11");
            }
            ClipboardUpdate::Set(snapshot) => {
                let source_fingerprint = snapshot.fingerprint();
                if *x11_state == ClipboardState::Content(source_fingerprint) {
                    debug!("ignoring X11 clipboard content already known to the bridge");

                    return Ok(());
                }
                *x11_state = ClipboardState::Content(source_fingerprint);

                let destination_fingerprint = snapshot.wayland_fingerprint();""",
        """\
            ClipboardUpdate::Cleared => {
                *x11_state = ClipboardState::Cleared;
                debug!("ignoring X11 clipboard clear to preserve Wayland clipboard");
            }
            ClipboardUpdate::Set(snapshot) => {
                if snapshot.total_bytes() == 0 {
                    debug!("ignoring empty X11 clipboard snapshot");
                    return Ok(());
                }
                let source_fingerprint = snapshot.fingerprint();
                let destination_fingerprint = snapshot.wayland_fingerprint();
                if *x11_state == ClipboardState::Content(source_fingerprint)
                    || *x11_state == ClipboardState::Content(destination_fingerprint)
                    || *wayland_state == ClipboardState::Content(source_fingerprint)
                    || *wayland_state == ClipboardState::Content(destination_fingerprint)
                {
                    debug!("ignoring X11 clipboard content already known to the bridge");

                    return Ok(());
                }
                *x11_state = ClipboardState::Content(source_fingerprint);""",
    )

    patch(
        "src/lib.rs",
        """\
            ClipboardUpdate::Cleared => {
                if *wayland_state == ClipboardState::Cleared {
                    return Ok(());
                }
                *wayland_state = ClipboardState::Cleared;

                x11.send(X11Command::Clear)
                    .context("failed to request X11 clipboard clearing")?;
                *x11_state = ClipboardState::Cleared;
                info!("cleared X11 clipboard from Wayland");
            }
            ClipboardUpdate::Set(snapshot) => {
                let source_fingerprint = snapshot.fingerprint();
                if *wayland_state == ClipboardState::Content(source_fingerprint) {
                    debug!("ignoring Wayland clipboard content already known to the bridge");

                    return Ok(());
                }
                *wayland_state = ClipboardState::Content(source_fingerprint);

                let x11_targets = snapshot.x11_targets();
                if x11_targets.is_empty() {
                    debug!("Wayland clipboard has no transferable X11 targets");

                    return Ok(());
                }
                let offer_count = x11_targets.len();
                let total_bytes = snapshot.total_bytes();
                let mime_types = x11_targets
                    .into_iter()
                    .map(|(mime_type, _)| mime_type)
                    .collect::<Vec<_>>()
                    .join(", ");
                x11.send(X11Command::Set(snapshot))
                    .context("failed to publish the clipboard to X11")?;
                *x11_state = ClipboardState::Content(source_fingerprint);""",
        """\
            ClipboardUpdate::Cleared => {
                *wayland_state = ClipboardState::Cleared;
                debug!("ignoring Wayland clipboard clear to preserve X11 clipboard");
            }
            ClipboardUpdate::Set(snapshot) => {
                if snapshot.total_bytes() == 0 {
                    debug!("ignoring empty Wayland clipboard snapshot");
                    return Ok(());
                }
                let source_fingerprint = snapshot.fingerprint();
                let destination_fingerprint = snapshot.x11_fingerprint();
                if *wayland_state == ClipboardState::Content(source_fingerprint)
                    || *wayland_state == ClipboardState::Content(destination_fingerprint)
                    || *x11_state == ClipboardState::Content(source_fingerprint)
                    || *x11_state == ClipboardState::Content(destination_fingerprint)
                {
                    debug!("ignoring Wayland clipboard content already known to the bridge");

                    return Ok(());
                }
                *wayland_state = ClipboardState::Content(source_fingerprint);

                let x11_targets = snapshot.x11_targets();
                if x11_targets.is_empty() {
                    debug!("Wayland clipboard has no transferable X11 targets");

                    return Ok(());
                }
                let offer_count = x11_targets.len();
                let total_bytes = snapshot.total_bytes();
                let mime_types = x11_targets
                    .into_iter()
                    .map(|(mime_type, _)| mime_type)
                    .collect::<Vec<_>>()
                    .join(", ");
                x11.send(X11Command::Set(snapshot))
                    .context("failed to publish the clipboard to X11")?;
                *x11_state = ClipboardState::Content(destination_fingerprint);""",
    )

    patch(
        "src/wayland.rs",
        """\
            let transfer = watcher
                .receive(selection, &mime_type)
                .with_context(|| format!("failed to receive Wayland MIME type {mime_type:?}"))?;
            let Transfer::Complete(data) = transfer else {
                return Ok(None);
            };
            ensure!(
                data.len() <= remaining_total,
                "Wayland clipboard exceeds its total size limit"
            );

            total_bytes += data.len();
            trace!(%mime_type, bytes = data.len(), "captured Wayland clipboard target");
            offers.push(Offer { mime_type, data });
        }

        Ok((!offers.is_empty()).then(|| Snapshot::new(offers)))""",
        """\
            let data = match watcher.receive(selection, &mime_type) {
                Ok(Transfer::Complete(data)) => data,
                Ok(_) => return Ok(None),
                Err(error) => {
                    debug!(%error, %mime_type, "skipping failed Wayland clipboard target");
                    continue;
                }
            };
            if data.is_empty() || data.len() > remaining_total {
                debug!(%mime_type, bytes = data.len(), "skipping empty or oversized Wayland clipboard target");
                continue;
            }

            total_bytes += data.len();
            trace!(%mime_type, bytes = data.len(), "captured Wayland clipboard target");
            offers.push(Offer { mime_type, data });
        }

        let snapshot = Snapshot::new(offers);
        Ok((snapshot.total_bytes() > 0).then_some(snapshot))""",
    )

    patch(
        "src/x11.rs",
        "Event::SelectionClear(_) => self.owned = None,",
        "Event::SelectionClear(_) => {},",
    )

    patch(
        "src/x11.rs",
        """\
                let value = self.request_target(change.timestamp, atom, target_limit)?;
                ensure!(
                    !value.exceeded_limit,
                    "clipboard target {mime_type:?} exceeds its size limit"
                );

                total_bytes += value.data.len();
                trace!(%mime_type, bytes = value.data.len(), "captured X11 clipboard target");
                offers.push(Offer {
                    mime_type,
                    data: value.data,
                });
            }

            self.drain_events()?;
            if self.pending_change.is_some() {
                return Ok(None);
            }

            Ok((!offers.is_empty()).then(|| Snapshot::new(offers)))""",
        """\
                let value = match self.request_target(change.timestamp, atom, target_limit) {
                    Ok(value) => value,
                    Err(error) => {
                        debug!(%error, %mime_type, "skipping failed X11 clipboard target");
                        continue;
                    }
                };
                if value.exceeded_limit || value.data.is_empty() {
                    debug!(%mime_type, bytes = value.data.len(), "skipping empty or oversized X11 clipboard target");
                    continue;
                }

                total_bytes += value.data.len();
                trace!(%mime_type, bytes = value.data.len(), "captured X11 clipboard target");
                offers.push(Offer {
                    mime_type,
                    data: value.data,
                });
            }

            self.drain_events()?;
            if self.pending_change.is_some() {
                return Ok(None);
            }

            let snapshot = Snapshot::new(offers);
            Ok((snapshot.total_bytes() > 0).then_some(snapshot))""",
    )
  '';

  xwayclip = inputs.xwayclip.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      ${pkgs.python3}/bin/python3 ${xwayclipPatch}
    '';
  });
in {
  home.packages = [ xwayclip ];

  systemd.user.services.wechat-x11-clipboard-bridge = {
    Unit = {
      Description = "Bidirectional X11/Wayland clipboard sync (xwayclip)";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = "${xwayclip}/bin/xwayclip";
      Restart = "on-failure";
      RestartSec = 2;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
