# 출시 빌드의 R8 규칙. 라이브러리(AdMob, Firebase, Compose)는 각자 규칙을 함께 싣는다.

# WorkManager(AdMob이 쓴다)의 Room 데이터베이스는 이름으로 만들어진다. 없으면 앱이 켜지자마자 멈춘다.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
