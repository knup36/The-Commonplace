import SwiftUI
import SwiftData

struct CollectionDropDelegate: DropDelegate {
    let targetCollection: Collection
    let collections: [Collection]
    @Binding var draggingCollection: Collection?
    let modelContext: ModelContext

    func performDrop(info: DropInfo) -> Bool {
        guard let dragging = draggingCollection else { return false }
        guard dragging.id != targetCollection.id else { return false }

        let fromIndex = collections.firstIndex(where: { $0.id == dragging.id })
        let toIndex = collections.firstIndex(where: { $0.id == targetCollection.id })

        guard let from = fromIndex, let to = toIndex else { return false }

        var reordered = collections
        reordered.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)

        for (index, collection) in reordered.enumerated() {
            collection.order = index
        }

        draggingCollection = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let dragging = draggingCollection,
              dragging.id != targetCollection.id else { return }

        let fromIndex = collections.firstIndex(where: { $0.id == dragging.id })
        let toIndex = collections.firstIndex(where: { $0.id == targetCollection.id })

        guard let from = fromIndex, let to = toIndex else { return }

        withAnimation {
            var reordered = collections
            reordered.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
            for (index, collection) in reordered.enumerated() {
                collection.order = index
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

// Keep old one as typealias just in case
typealias CardDropDelegate = CollectionDropDelegate
