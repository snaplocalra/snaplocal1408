import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:snap_local/bottom_bar/bottom_bar_modules/explore/screen/explore_screen.dart';
import 'package:snap_local/bottom_bar/bottom_bar_modules/home/logic/connection_connect/connection_connect_cubit.dart';
import 'package:snap_local/bottom_bar/bottom_bar_modules/home/logic/connection_ignore/connection_ignore_cubit.dart';
import 'package:snap_local/bottom_bar/bottom_bar_modules/home/logic/local_connections/local_connections_cubit.dart';
import 'package:snap_local/bottom_bar/bottom_bar_modules/home/logic/local_connections/local_connections_state.dart';
import 'package:snap_local/bottom_bar/bottom_bar_modules/home/widgets/common/see_all_button.dart';
import 'package:snap_local/profile/profile_details/neighbours_profile/screen/neigbours_profile_screen.dart';
import 'package:snap_local/utility/common/widgets/shimmer_widget.dart';

import '../../../../../utility/constant/assets_images.dart';

class ConnectionsSection extends StatefulWidget {
  const ConnectionsSection({super.key});

  @override
  State<ConnectionsSection> createState() => _ConnectionsSectionState();
}

class _ConnectionsSectionState extends State<ConnectionsSection> {
  final ScrollController _scrollController = ScrollController();
  double _savedOffset = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocalConnectionsCubit>().loadConnections();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _refreshConnections() {
    _savedOffset = _scrollController.offset;
    context.read<LocalConnectionsCubit>().loadConnections();
  }

  void _restoreScrollOffset() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_savedOffset);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LocalConnectionsCubit, LocalConnectionsState>(
      listenWhen: (previous, current) =>
      previous.dataLoading && !current.dataLoading,
      listener: (context, state) {
        _restoreScrollOffset();
      },
      buildWhen: (prev, curr) =>
      prev.connections != curr.connections ||
          prev.dataLoading != curr.dataLoading,
      builder: (context, state) {
        if (state.dataLoading) {
          return _buildLoadingState();
        }

        if (state.error != null || state.connections.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Connections you may like',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A237E),
                    ),
                  ),
                  SeeAllButton(
                    onTap: () {
                      GoRouter.of(context).pushNamed(
                        ExploreScreen.routeName,
                        extra: true,
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: state.connections.length,
                itemBuilder: (context, index) {
                  final connection = state.connections[index];
                  return _buildConnectionCard(connection);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildConnectionCard(dynamic connection) {
    return GestureDetector(
      onTap: () {
        GoRouter.of(context).pushNamed(
          NeighboursProfileAndPostsScreen.routeName,
          queryParameters: {'id': connection.id},
        );
      },
      child: Container(
        width: 180,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade50,
              Colors.grey.shade100,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage: NetworkImage(connection.image),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  connection.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A237E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if(connection.isVerified==true)...[
                  const SizedBox(width: 2),
                  SvgPicture.asset(
                    SVGAssetsImages.greenTick,
                    height: 12,
                    width: 12,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            _buildConnectionActions(connection),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionActions(dynamic connection) {
    final status = connection.connectionStatus.connectionStatus;
    final isSender = connection.connectionStatus.isConnectionRequestSender;
    final connectionId = connection.connectionStatus.connectionId.toString();

    if (status == 'not_connected') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          BlocBuilder<ConnectionConnectCubit, ConnectionConnectState>(
            builder: (context, connectState) {
              final isConnecting = connectState is ConnectionConnectLoading &&
                  connectState.userId == connection.id;
              return ElevatedButton(
                onPressed: isConnecting
                    ? null
                    : () {
                  context
                      .read<ConnectionConnectCubit>()
                      .handleConnection(connection.id)
                      .then((_) => _refreshConnections());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: isConnecting
                    ? const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : const Text('Connect', style: TextStyle(fontSize: 10)),
              );
            },
          ),
          const SizedBox(width: 8),
          BlocBuilder<ConnectionIgnoreCubit, ConnectionIgnoreState>(
            builder: (context, ignoreState) {
              final isIgnoring = ignoreState is ConnectionIgnoreLoading &&
                  ignoreState.userId == connection.id;
              return ElevatedButton(
                onPressed: isIgnoring
                    ? null
                    : () {
                  context
                      .read<ConnectionIgnoreCubit>()
                      .ignoreConnection(connection.id)
                      .then((_) => _refreshConnections());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade200,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: isIgnoring
                    ? const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : const Text('Ignore', style: TextStyle(fontSize: 10)),
              );
            },
          ),
        ],
      );
    }

    if (status == 'request_pending') {
      if (isSender) {
        return BlocBuilder<ConnectionConnectCubit, ConnectionConnectState>(
          builder: (context, connectState) {
            final isCancelling = connectState is ConnectionConnectLoading &&
                connectState.userId == connection.id;
            return ElevatedButton(
              onPressed: isCancelling
                  ? null
                  : () {
                context
                    .read<ConnectionConnectCubit>()
                    .handleConnection(connection.id, isCancel: true)
                    .then((_) => _refreshConnections());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: isCancelling
                  ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : const Text('Cancel Request', style: TextStyle(fontSize: 10)),
            );
          },
        );
      } else {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            BlocBuilder<ConnectionConnectCubit, ConnectionConnectState>(
              builder: (context, connectState) {
                final isAccepting = connectState is ConnectionConnectLoading &&
                    connectState.userId == connectionId;
                return ElevatedButton(
                  onPressed: isAccepting
                      ? null
                      : () {
                    context
                        .read<ConnectionConnectCubit>()
                        .acceptConnection(connectionId)
                        .then((_) => _refreshConnections());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 77, 216, 82),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: isAccepting
                      ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : const Text('Accept', style: TextStyle(fontSize: 10)),
                );
              },
            ),
            const SizedBox(width: 8),
            BlocBuilder<ConnectionConnectCubit, ConnectionConnectState>(
              builder: (context, connectState) {
                final isRejecting = connectState is ConnectionConnectLoading &&
                    connectState.userId == connectionId;
                return ElevatedButton(
                  onPressed: isRejecting
                      ? null
                      : () {
                    context
                        .read<ConnectionConnectCubit>()
                        .rejectConnection(connectionId)
                        .then((_) => _refreshConnections());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: isRejecting
                      ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : const Text('Reject', style: TextStyle(fontSize: 10)),
                );
              },
            ),
          ],
        );
      }
    }

    return const SizedBox.shrink();
  }

  Widget _buildLoadingState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShimmerWidget(width: 180, height: 20),
              ShimmerWidget(width: 60, height: 20),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: 3,
            itemBuilder: (context, index) {
              return const Padding(
                padding: EdgeInsets.only(right: 12),
                child: ShimmerWidget(width: 160, height: 160),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
