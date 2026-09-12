import SwiftUI

struct MatchedGeometryExample: View {
    @Namespace private var namespace
    @State private var isExpanded = false
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            if !isExpanded {
                // Collapsed State: Thumbnail Card
                VStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .matchedGeometryEffect(id: "background", in: namespace)
                        .frame(width: 120, height: 120)
                        .overlay(
                            Image(systemName: "sparkles")
                                .font(.largeTitle)
                                .foregroundColor(.white)
                                .matchedGeometryEffect(id: "icon", in: namespace)
                        )
                    
                    Text("Tap to Expand")
                        .font(.headline)
                        .matchedGeometryEffect(id: "title", in: namespace)
                }
                .padding()
                .onTapGesture {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }
            } else {
                // Expanded State: Full Hero Screen
                VStack(spacing: 20) {
                    RoundedRectangle(cornerRadius: 32)
                        .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .matchedGeometryEffect(id: "background", in: namespace)
                        .frame(height: 300)
                        .overlay(
                            Image(systemName: "sparkles")
                                .font(.system(size: 80))
                                .foregroundColor(.white)
                                .matchedGeometryEffect(id: "icon", in: namespace)
                        )
                    
                    Text("Tap to Reduce")
//                        .font(.largeTitle)
                        .bold()
                        .matchedGeometryEffect(id: "title", in: namespace)
                    
                    Text("This view morphed smoothly using matchedGeometryEffect. Both states share unique IDs within the same @Namespace.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        
                    
                    Spacer()
                }
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .scale(scale: 0.82).combined(with: .opacity)
                    )
                )
                .padding()
                .onTapGesture {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }
            }
        }
    }
}
#Preview {
    MatchedGeometryExample()
}
