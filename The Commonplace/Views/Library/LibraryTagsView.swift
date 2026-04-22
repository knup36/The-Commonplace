// LibraryTagsView.swift
// Commonplace
//
// The Tags segment of LibraryView, extracted for clarity.
// Displays tags organised into user-defined groups via TagGroupService.
//
// Groups render as collapsible List sections. Tags can be moved between
// groups via long press → "Move to Group" picker. Groups can be renamed
// or deleted via long press on the section header. Tags within a group
// can be reordered via drag handle.
//
// Ungrouped tags always appear at the bottom in their own section.
// A "+ New Group" row sits at the very bottom of the list.

import SwiftUI
import SwiftData

struct LibraryTagsView: View {
    let allTags: [(tag: String, count: Int)]
    let allTagObjects: [Tag]
    let style: any AppThemeStyle
    
    @Environment(\.modelContext) var modelContext
    @StateObject private var groupService = TagGroupService.shared
    
    // MARK: - Local state
    
    @State private var showingNewGroupAlert = false
    @State private var newGroupName = ""
    @State private var tagToMove: String? = nil
    @State private var showingMoveSheet = false
    @State private var groupToRename: String? = nil
    @State private var renameGroupText = ""
    @State private var showingRenameAlert = false
    @State private var groupToDelete: String? = nil
    @State private var showingDeleteConfirm = false
    @State private var expandedGroups: Set<String> = []
    @Binding var isEditingGroups: Bool
    
    // MARK: - Derived data
    
    var ungroupedTags: [(tag: String, count: Int)] {
        allTags.filter { groupService.group(for: $0.tag) == nil }
    }
    
    func tagsInGroup(_ groupName: String) -> [(tag: String, count: Int)] {
        let ordered = groupService.tags(in: groupName)
        // Preserve group order, fall back to allTags order for new tags
        let tagMap = Dictionary(uniqueKeysWithValues: allTags.map { ($0.tag, $0.count) })
        return ordered.compactMap { name in
            guard let count = tagMap[name] else { return nil }
            return (tag: name, count: count)
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        if allTags.isEmpty {
            emptyState
        } else {
            groupedContent
        }
    }
    
    // MARK: - Empty state
    
    var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tag.slash")
                .font(.system(size: 48))
                .foregroundStyle(style.tertiaryText)
            Text("No Tags Yet")
                .font(style.typeTitle3)
                .foregroundStyle(style.secondaryText)
            Text("Add tags to your entries to see them here")
                .font(style.typeCaption)
                .foregroundStyle(style.tertiaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
    
    // MARK: - Grouped content
    
    @ViewBuilder
    var groupedContent: some View {
        
        // Edit groups mode — flat reorderable list
        if isEditingGroups {
            Section {
                ForEach(groupService.groupOrder, id: \.self) { groupName in
                    HStack(spacing: 10) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 14))
                            .foregroundStyle(style.tertiaryText)
                        Text(groupName)
                            .font(style.typeBody)
                            .fontWeight(.semibold)
                            .foregroundStyle(style.primaryText)
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.clear)
                }
                .onMove { from, to in
                    groupService.moveGroups(from: from, to: to)
                }
            }
        } else {
            
            // Normal grouped view
            ForEach(groupService.groupOrder, id: \.self) { groupName in
                Section {
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedGroups.contains(groupName) },
                            set: { if $0 { expandedGroups.insert(groupName) } else { expandedGroups.remove(groupName) } }
                        )
                    ) {
                        let tags = tagsInGroup(groupName)
                        ForEach(tags, id: \.tag) { item in
                            tagRow(item: item)
                        }
                        .onMove { from, to in
                            groupService.moveTags(in: groupName, from: from, to: to)
                        }
                    } label: {
                        HStack {
                            Text(groupName)
                                .font(style.typeBody)
                                .fontWeight(.semibold)
                                .foregroundStyle(style.primaryText)
                                .textCase(nil)
                                .contextMenu {
                                    Button {
                                        groupToRename = groupName
                                        renameGroupText = groupName
                                        showingRenameAlert = true
                                    } label: {
                                        Label("Rename", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        groupToDelete = groupName
                                        showingDeleteConfirm = true
                                    } label: {
                                        Label("Delete Group", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listRowBackground(Color.clear)
                }
            }
            
            // Ungrouped section
            if !ungroupedTags.isEmpty {
                Section {
                    ForEach(ungroupedTags, id: \.tag) { item in
                        tagRow(item: item)
                    }
                } header: {
                    Text("Ungrouped")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(style.tertiaryText)
                        .textCase(nil)
                }
            }
            
            // + New Group row
            Section {
                Button {
                    newGroupName = ""
                    showingNewGroupAlert = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(style.accent)
                        Text("New Group")
                            .font(style.typeBody)
                            .foregroundStyle(style.accent)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        
        // Sheets and alerts
        Color.clear
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .frame(height: 0)
            .alert("New Group", isPresented: $showingNewGroupAlert) {
                TextField("Group name", text: $newGroupName)
                Button("Create") {
                    let trimmed = newGroupName.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        groupService.createGroup(name: trimmed)
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Rename Group", isPresented: $showingRenameAlert) {
                TextField("Group name", text: $renameGroupText)
                Button("Rename") {
                    if let old = groupToRename {
                        let trimmed = renameGroupText.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty {
                            groupService.renameGroup(from: old, to: trimmed)
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Delete Group?", isPresented: $showingDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    if let name = groupToDelete {
                        groupService.deleteGroup(name: name)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Tags in this group will become ungrouped.")
            }
            .sheet(isPresented: $showingMoveSheet) {
                moveToGroupSheet
            }
    }
    
    // MARK: - Tag row
    
    func tagRow(item: (tag: String, count: Int)) -> some View {
        ZStack {
            NavigationLink(destination: TagFeedView(tag: item.tag)) {
                EmptyView()
            }
            .opacity(0)
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "number")
                        .font(.caption)
                        .foregroundStyle(style.accent)
                    Text(item.tag)
                        .font(style.typeBody)
                        .foregroundStyle(style.primaryText)
                }
                Spacer()
                Text("\(item.count)")
                    .font(style.typeBodySecondary)
                    .fontWeight(.semibold)
                    .foregroundStyle(style.accent)
                    .padding(.trailing, -12)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 24))
        .listRowSeparator(.visible)
        .buttonStyle(.plain)
        .swipeActions(edge: .leading) {
            Button {
                if let tag = allTagObjects.first(where: { $0.name == item.tag }) {
                    tag.isPinned.toggle()
                }
            } label: {
                let isPinned = allTagObjects.first(where: { $0.name == item.tag })?.isPinned == true
                Label(
                    isPinned ? "Unbookmark" : "Bookmark",
                    systemImage: isPinned ? "bookmark.slash.fill" : "bookmark.fill"
                )
            }
            .tint(.orange)
        }
        .swipeActions(edge: .trailing) {
            Button {
                tagToMove = item.tag
                showingMoveSheet = true
            } label: {
                Label("Move to Group", systemImage: "folder")
            }
            .tint(.blue)
        }
    }
    
    // MARK: - Move to group sheet
    
    var moveToGroupSheet: some View {
        NavigationStack {
            List {
                // Existing groups
                ForEach(groupService.groupOrder, id: \.self) { groupName in
                    Button {
                        if let tag = tagToMove {
                            groupService.assign(tag: tag, to: groupName)
                        }
                        showingMoveSheet = false
                    } label: {
                        HStack {
                            Text(groupName)
                                .font(style.typeBody)
                                .foregroundStyle(style.primaryText)
                            Spacer()
                            if let tag = tagToMove, groupService.group(for: tag) == groupName {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(style.accent)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                // Ungrouped option
                Button {
                    if let tag = tagToMove {
                        groupService.ungroup(tag: tag)
                    }
                    showingMoveSheet = false
                } label: {
                    HStack {
                        Text("Ungrouped")
                            .font(style.typeBody)
                            .foregroundStyle(style.secondaryText)
                        Spacer()
                        if let tag = tagToMove, groupService.group(for: tag) == nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(style.accent)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(style.background.ignoresSafeArea())
            .navigationTitle("Move to Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingMoveSheet = false }
                }
            }
        }
    }
}
