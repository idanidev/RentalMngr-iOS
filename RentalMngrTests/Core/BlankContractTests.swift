import Foundation
import PDFKit
import Testing

@testable import RentalMngr

/// El contrato en modo plantilla.
///
/// Lo que tiene que cumplir es sencillo de decir y fácil de romper sin darse
/// cuenta: **no puede colarse ningún dato**. Si alguien añade una variable nueva
/// al generador y se olvida del modo plantilla, el nombre de un inquilino real
/// acabaría impreso en un contrato que se reparte en blanco.
@MainActor
struct BlankContractTests {

    private let plantilla = """
        CONTRATO DE ARRENDAMIENTO

        Arrendador: {{landlord_name}}, con DNI {{landlord_dni}}.
        Arrendatario: {{tenant_name}}, con DNI {{tenant_dni}}.
        Domicilio: {{property_address}}
        Habitación: {{room_name}}
        Renta: {{rent}} al mes. Fianza: {{deposit}}.
        Desde {{start_date}} hasta {{end_date}}.
        """

    private func property() -> Property {
        makeProperty(name: "Piso de prueba")
    }

    private func room(_ propertyId: UUID) -> Room {
        makeRoom(propertyId: propertyId, rent: 1234)
    }

    private func tenant(_ propertyId: UUID) -> Tenant {
        Tenant(
            id: UUID(), propertyId: propertyId,
            fullName: "Zacarias Quintanilla", dni: "00000000X",
            contractStartDate: Date(), contractEndDate: Date().addingTimeInterval(86_400 * 180),
            depositAmount: 4321, currentAddress: "Calle Inventada 99", active: true)
    }

    private let landlord = LandlordProfile(
        fullName: "Wenceslao Trujillo", dni: "11111111Y",
        address: "", email: "", phone: nil)

    // Los testigos no llevan guiones bajos ni asteriscos a propósito: el
    // generador interpreta Markdown, y "NOMBRE_DE_PRUEBA" se convertiría en
    // cursiva y perdería los guiones. Entonces el test de "no se cuela nada"
    // pasaría aunque el nombre SÍ se colara, que es justo lo que tiene que pillar.
    private func texto(of data: Data) throws -> String {
        try #require(PDFDocument(data: data)?.string)
    }

    @Test("En blanco no aparece ningún dato, ni siquiera el del arrendador")
    func blankLeaksNothing() async throws {
        let prop = property()
        let data = try await PDFGenerator().generateContract(
            tenant: tenant(prop.id), room: room(prop.id), property: prop, landlord: landlord,
            template: plantilla, blankTemplate: true)

        let salida = try texto(of: data)
        for dato in ["Zacarias Quintanilla", "00000000X", "Wenceslao Trujillo",
                     "11111111Y", "1234", "4321"] {
            #expect(!salida.contains(dato), "se ha colado \(dato)")
        }
        // Y las cláusulas sí tienen que estar: es la plantilla de la propiedad.
        #expect(salida.contains("CONTRATO DE ARRENDAMIENTO"))
        #expect(salida.contains("Arrendatario"))
        // Con huecos donde iban los datos.
        #expect(salida.contains("____"))
    }

    @Test("Sin modo plantilla, los datos sí salen")
    func normalContractFillsData() async throws {
        let prop = property()
        let data = try await PDFGenerator().generateContract(
            tenant: tenant(prop.id), room: room(prop.id), property: prop, landlord: landlord,
            template: plantilla)

        let salida = try texto(of: data)
        #expect(salida.contains("Zacarias Quintanilla"))
        #expect(salida.contains("Wenceslao Trujillo"))
        #expect(salida.contains("1234"))
    }

    @Test("Se puede pedir en blanco sin inquilino ni arrendador")
    func worksWithoutTenant() async throws {
        // Es el caso real: la plantilla se pide desde la propiedad, y ahí puede
        // no haber todavía ningún inquilino.
        let data = try await PDFGenerator().generateContract(
            property: property(), template: plantilla, blankTemplate: true)

        let salida = try texto(of: data)
        #expect(salida.contains("CONTRATO DE ARRENDAMIENTO"))
        #expect(salida.contains("____"))
    }

    @Test("Las variables propias también salen como hueco, no desaparecen")
    func customVariablesBecomeBlanks() async throws {
        // `templateKey` se deriva del nombre: "plaza_garaje" → "{{plaza_garaje}}".
        let variable = ContractVariable(
            id: UUID(), name: "plaza_garaje", label: "Plaza de garaje",
            defaultValue: "Plaza numero siete", userId: nil, createdAt: nil)

        let data = try await PDFGenerator().generateContract(
            property: property(),
            template: "Garaje: {{plaza_garaje}}",
            customVariables: [variable],
            blankTemplate: true)

        let salida = try texto(of: data)
        #expect(!salida.contains("Plaza numero siete"))
        #expect(salida.contains("Garaje:"))
        #expect(salida.contains("____"))
    }

    @Test("Con mis datos: sale el arrendador y nada del inquilino")
    func includeLandlordKeepsOnlyLandlord() async throws {
        let prop = property()
        let data = try await PDFGenerator().generateContract(
            tenant: tenant(prop.id), room: room(prop.id), property: prop, landlord: landlord,
            template: plantilla, blankTemplate: true, includeLandlord: true)

        let salida = try texto(of: data)
        // Lo mío, puesto.
        #expect(salida.contains("Wenceslao Trujillo"))
        #expect(salida.contains("11111111Y"))
        // Lo del inquilino y los importes, en blanco aunque se hayan pasado.
        for dato in ["Zacarias Quintanilla", "00000000X", "1234", "4321"] {
            #expect(!salida.contains(dato), "se ha colado \(dato)")
        }
        #expect(salida.contains("____"))
    }

    @Test("La opción solo tiene efecto en blanco: un contrato normal no cambia")
    func includeLandlordIgnoredWhenNotBlank() async throws {
        let prop = property()
        let data = try await PDFGenerator().generateContract(
            tenant: tenant(prop.id), room: room(prop.id), property: prop, landlord: landlord,
            template: plantilla, includeLandlord: true)

        let salida = try texto(of: data)
        #expect(salida.contains("Zacarias Quintanilla"))
        #expect(salida.contains("Wenceslao Trujillo"))
    }

    @Test("En blanco, la dirección de la vivienda sale puesta")
    func blankKeepsPropertyAddress() async throws {
        // Es la de la propia vivienda desde la que se saca el contrato: no cambia
        // de un inquilino a otro. makeProperty la pone en "Calle Mayor 1".
        let prop = property()
        for conMisDatos in [false, true] {
            let data = try await PDFGenerator().generateContract(
                tenant: tenant(prop.id), room: room(prop.id), property: prop, landlord: landlord,
                template: plantilla, blankTemplate: true, includeLandlord: conMisDatos)
            let salida = try texto(of: data)
            #expect(salida.contains("Calle Mayor 1"))
            // La dirección anterior del inquilino, en cambio, es suya: en blanco.
            #expect(!salida.contains("Calle Inventada 99"))
        }
    }
}
