import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../services/proxy_app_controller.dart';
import '../../widgets/clash_widgets.dart';
import 'help_about_pages.dart';
import '../profile/profile_list_page.dart';
import '../proxy/proxy_page.dart';
import '../settings/settings_pages.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final ProxyAppController controller;

  @override
  void initState() {
    super.initState();
    controller = ProxyAppController();
    controller.initialize();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _openProxy() {
    if (!controller.isRunning) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请先启动 VPN 代理')));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProxyPage(controller: controller)),
    );
  }

  void _openProfiles() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => ProfileListPage(controller: controller)),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(30, 25, 30, 30),
          children: [
            const Row(
              children: [
                SizedBox(width: 14),
                AppIcon(size: 40),
                SizedBox(width: 17),
                Expanded(
                  child: Text(
                    'Clash RS',
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: 'ClashSerif',
                      fontSize: 17,
                      letterSpacing: .5,
                      color: AppColors.text,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            SizedBox(
              height: 85,
              child: ClashCard(
                color: controller.isRunning
                    ? AppColors.blue
                    : AppColors.cardElevated,
                onTap: controller.ready && !controller.busy
                    ? controller.toggle
                    : null,
                child: Row(
                  children: [
                    SizedBox(
                      width: 50,
                      child: controller.busy
                          ? const Center(
                              child: SizedBox.square(
                                dimension: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : Icon(
                              controller.isRunning
                                  ? Icons.check_circle_outline
                                  : Icons.do_not_disturb_on_outlined,
                              size: 28,
                              color: Colors.white,
                            ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            controller.isRunning ? '运行中' : '已停止',
                            style: const TextStyle(
                              fontSize: 17,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            controller.isRunning
                                ? '${formatBytes(controller.totalUp + controller.totalDown)} 已转发'
                                : '点此启动',
                            style: const TextStyle(
                              fontSize: 14.5,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (controller.isRunning) ...[
              SizedBox(
                height: 85,
                child: ClashCard(
                  color: AppColors.cardElevated,
                  onTap: _openProxy,
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 50,
                        child: Icon(Icons.grid_view, size: 27),
                      ),
                      const SizedBox(width: 11),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            '代理',
                            style: TextStyle(
                              fontSize: 14.5,
                              letterSpacing: 1.3,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            '规则模式',
                            style: TextStyle(fontSize: 12.5, letterSpacing: 1),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              height: 85,
              child: ClashCard(
                color: AppColors.cardElevated,
                onTap: _openProfiles,
                child: Row(
                  children: [
                    const SizedBox(
                      width: 50,
                      child: Icon(Icons.view_list, size: 29),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '配置',
                            style: TextStyle(
                              fontSize: 14.5,
                              letterSpacing: 1.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${controller.activeProfile?.name ?? '新配置'} 已激活',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              letterSpacing: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            MenuRow(
              icon: Icons.assignment,
              title: '日志',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _LogsPage(controller: controller),
                ),
              ),
            ),
            MenuRow(
              icon: Icons.settings,
              title: '设置',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsPage(controller: controller),
                ),
              ),
            ),
            MenuRow(
              icon: Icons.help,
              title: '帮助',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HelpPage()),
              ),
            ),
            MenuRow(
              icon: Icons.info,
              title: '关于',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AboutPage(controller: controller),
                ),
              ),
            ),
            if (controller.error != null) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: controller.clearError,
                child: Text(
                  controller.error!,
                  style: const TextStyle(
                    color: Color(0xFFFF8A80),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _LogsPage extends StatelessWidget {
  final ProxyAppController controller;
  const _LogsPage({required this.controller});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const ScreenshotAppBar(title: '日志'),
    body: controller.logs.isEmpty
        ? const Center(child: Text('暂无日志'))
        : ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: controller.logs.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (_, index) => Text(
              controller.logs[index],
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
  );
}
