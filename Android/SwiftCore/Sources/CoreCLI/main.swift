import Foundation
import Glibc
import VetPilotCore
while let line = readLine() { print(VetPilotBridge.dispatch(line)); fflush(stdout) }
