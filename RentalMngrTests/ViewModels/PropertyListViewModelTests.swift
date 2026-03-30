import Testing
import Foundation
@testable import RentalMngr

@Suite("PropertyListViewModel")
@MainActor
struct PropertyListViewModelTests {

    // MARK: - Initial state

    @Test("starts with empty state and not loading")
    func initialState() {
        let vm = makeVM()
        #expect(vm.properties.isEmpty)
        #expect(vm.isLoading == false)
        #expect(vm.errorMessage == nil)
    }

    // MARK: - loadProperties

    @Test("loadProperties populates properties from service")
    func loadPopulatesProperties() async {
        let service = MockPropertyService()
        service.stubbedProperties = [makeProperty(name: "Flat A"), makeProperty(name: "Flat B")]
        let vm = makeVM(propertyService: service)

        await vm.loadProperties()

        #expect(vm.properties.count == 2)
        #expect(vm.isLoading == false)
        #expect(vm.errorMessage == nil)
    }

    @Test("loadProperties sets isLoaded so a second call is skipped")
    func loadOnlyFetchesOnce() async {
        let service = MockPropertyService()
        service.stubbedProperties = [makeProperty()]
        let vm = makeVM(propertyService: service)

        await vm.loadProperties()
        // Change stub so we'd know if it fires again
        service.stubbedProperties = [makeProperty(), makeProperty(), makeProperty()]
        await vm.loadProperties()

        // Should still have 1 — the second call was skipped by the guard
        #expect(vm.properties.count == 1)
    }

    @Test("loadProperties sets errorMessage on service failure")
    func loadSetsErrorOnFailure() async {
        let service = MockPropertyService()
        service.stubbedError = MockError.forced("network error")
        let vm = makeVM(propertyService: service)

        await vm.loadProperties()

        #expect(vm.properties.isEmpty)
        #expect(vm.errorMessage != nil)
        #expect(vm.isLoading == false)
    }

    @Test("loadProperties sets isLoaded even on failure")
    func loadSetsIsLoadedOnError() async {
        let service = MockPropertyService()
        service.stubbedError = MockError.forced("network error")
        let vm = makeVM(propertyService: service)

        await vm.loadProperties()

        // isLoaded = true even on error — prevents infinite retry loops
        #expect(vm.isLoaded == true)
    }

    // MARK: - refresh

    @Test("refresh resets isLoaded and fetches again")
    func refreshFetchesAgain() async {
        let service = MockPropertyService()
        service.stubbedProperties = [makeProperty()]
        let vm = makeVM(propertyService: service)

        await vm.loadProperties()
        #expect(vm.properties.count == 1)

        service.stubbedProperties = [makeProperty(), makeProperty()]
        await vm.refresh()

        #expect(vm.properties.count == 2)
    }

    @Test("refresh clears previous error")
    func refreshClearsPreviousError() async {
        let service = MockPropertyService()
        service.stubbedError = MockError.forced("error")
        let vm = makeVM(propertyService: service)

        await vm.loadProperties()
        #expect(vm.errorMessage != nil)

        service.stubbedError = nil
        service.stubbedProperties = [makeProperty()]
        await vm.refresh()

        #expect(vm.errorMessage == nil)
        #expect(vm.properties.count == 1)
    }

    // MARK: - deleteProperty

    @Test("deleteProperty removes property from local list")
    func deleteRemovesFromList() async {
        let service = MockPropertyService()
        let p1 = makeProperty(name: "Keep")
        let p2 = makeProperty(name: "Delete")
        service.stubbedProperties = [p1, p2]
        let vm = makeVM(propertyService: service)

        await vm.loadProperties()
        await vm.deleteProperty(p2)

        #expect(vm.properties.count == 1)
        #expect(vm.properties.first?.name == "Keep")
    }

    @Test("deleteProperty calls service delete")
    func deleteCallsService() async {
        let service = MockPropertyService()
        let property = makeProperty()
        service.stubbedProperties = [property]
        let vm = makeVM(propertyService: service)

        await vm.loadProperties()
        await vm.deleteProperty(property)

        #expect(service.deleteCallCount == 1)
        #expect(service.lastDeletedId == property.id)
    }

    @Test("deleteProperty sets errorMessage when service fails")
    func deleteErrorSetsMessage() async {
        let service = MockPropertyService()
        let property = makeProperty()
        service.stubbedProperties = [property]
        let vm = makeVM(propertyService: service)
        await vm.loadProperties()

        service.stubbedError = MockError.forced("delete failed")
        await vm.deleteProperty(property)

        // List should not change (delete failed)
        #expect(vm.properties.count == 1)
        #expect(vm.errorMessage != nil)
    }
}

// MARK: - Helpers

@MainActor
private func makeVM(
    propertyService: MockPropertyService = MockPropertyService(),
    realtimeService: MockRealtimeService = MockRealtimeService()
) -> PropertyListViewModel {
    PropertyListViewModel(propertyService: propertyService, realtimeService: realtimeService)
}
